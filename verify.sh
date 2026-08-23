set -uo pipefail
PASS = true

echo "Checking VM status..."
for vm in db backend frontend; do
  state=$(vagrant status --machine-readable | grep "^[0-9]*,$vm,state," | cut -d, -f4)
  if [ "$state" != "running" ]; then
    echo "FAIL: $vm is not running (state: $state)"
    PASS=false
  else
    echo "Great, the $vm is running"
  fi
done
echo "---------------"
echo "Checking backend health..."
HEALTH=$(curl -sf http://localhost:5000/api/health || echo "")
if echo "$HEALTH" | grep -q '"status":"ok"'; then
  echo "Great, the backend healthy"
else
  echo "FAIL: backend health check failed"
  PASS=false
fi

echo "---------------"

echo "Checking database connection and seed data..."
DASHBOARD=$(curl -sf http://localhost:5000/api/dashboard || echo "")
ASSET_COUNT=$(echo "$DASHBOARD" | grep -o '"totalAssets":[0-9]*' | grep -o '[0-9]*')

if [[ "$ASSET_COUNT" =~ ^[0-9]+$ ]] && [ "$ASSET_COUNT" -ge 20 ]; then
  echo "Great, database reachable, $ASSET_COUNT assets found"
else
  echo "FAIL: expected at least 20 seeded assets, got: '$ASSET_COUNT'"
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