set -uo pipefail
cd "$(dirname "$0")/infra"

PASS=true
REGION=us-east-1

echo "Checking EC2 instances..."
for name in sentinel-backend sentinel-frontend; do
  state=$(aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=$name" "Name=instance-state-name,Values=pending,running" --query "Reservations[0].Instances[0].State.Name" --output text 2>/dev/null)
  if [ "$state" != "running" ]; then
    echo "FAIL: $name is not running (state: $state)"
    PASS=false
  else
    echo "Great, $name is running"
  fi
done

echo "---------------"
echo "Checking RDS..."
RDS_STATE=$(aws rds describe-db-instances --region $REGION --db-instance-identifier sentinel-db --query "DBInstances[0].DBInstanceStatus" --output text 2>/dev/null)
if [ "$RDS_STATE" != "available" ]; then
  echo "FAIL: RDS not available (state: $RDS_STATE)"
  PASS=false
else
  echo "Great, RDS is available"
fi

echo "---------------"
BACKEND_IP=$(terraform output -raw backend_public_ip)
FRONTEND_IP=$(terraform output -raw frontend_public_ip)

echo "Checking backend health..."
HEALTH=$(curl -sf http://$BACKEND_IP:5000/api/health || echo "")
if echo "$HEALTH" | grep -q '"status":"ok"'; then
  echo "Great, the backend healthy"
else
  echo "FAIL: backend health check failed"
  PASS=false
fi

echo "---------------"
echo "Checking frontend..."
CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$FRONTEND_IP:3000/)
if [ "$CODE" = "200" ]; then
  echo "Great, the frontend is up"
else
  echo "FAIL: frontend returned $CODE"
  PASS=false
fi

echo "---------------"
echo "Checking asset write/read through RDS..."
NAME="verify-$(date +%s)"
RESP=$(curl -sf -X POST http://$BACKEND_IP:5000/api/assets -H "Content-Type: application/json" -d "{\"name\":\"$NAME\",\"assetType\":\"Server\",\"owner\":\"verify\"}")
ID=$(echo "$RESP" | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')

if [ -n "$ID" ]; then
  READBACK=$(curl -sf http://$BACKEND_IP:5000/api/assets)
  if echo "$READBACK" | grep -q "$NAME"; then
    echo "Great, wrote and read back an asset (id $ID)"
    curl -sf -X DELETE http://$BACKEND_IP:5000/api/assets/$ID > /dev/null
  else
    echo "FAIL: couldn't read back the asset"
    PASS=false
  fi
else
  echo "FAIL: couldn't create test asset"
  PASS=false
fi

echo "---------------"
echo ""
if [ "$PASS" = true ]; then
  echo "All checks passed."
  exit 0
else
  echo "One or more checks failed."
  exit 1
fi
