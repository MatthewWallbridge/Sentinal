#!/bin/bash
set -euo pipefail

apt-get update -y
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs postgresql-client git

cd /home/ubuntu
git clone https://github.com/MatthewWallbridge/Sentinal.git app
cd app/backend

cat > .env << ENVEOF
DATABASE_URL=postgresql://sentinel:${db_password}@${rds_endpoint}/sentinel_db
PORT=5000
ENVEOF

npm install

PGPASSWORD=${db_password} psql -h ${rds_host} -U sentinel -d sentinel_db -f sql/schema.sql

ASSET_COUNT=$(PGPASSWORD=${db_password} psql -h ${rds_host} -U sentinel -d sentinel_db -t -c "SELECT count(*) FROM assets;" | tr -d '[:space:]')
if [ "$ASSET_COUNT" = "0" ]; then
  PGPASSWORD=${db_password} psql -h ${rds_host} -U sentinel -d sentinel_db -f sql/seed.sql
fi

cat > /etc/systemd/system/sentinel-backend.service << SERVICEEOF
[Unit]
Description=Sentinel backend API
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/ubuntu/app/backend
ExecStart=/usr/bin/node /home/ubuntu/app/backend/index.js
Restart=on-failure
User=ubuntu
EnvironmentFile=/home/ubuntu/app/backend/.env

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable sentinel-backend
systemctl restart sentinel-backend