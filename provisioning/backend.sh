#!/usr/bin/env bash
set -euo pipefail

# Node.js 20.x via NodeSource
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
apt-get install -y nodejs

# psql client, so this VM can talk to the db VM
apt-get install -y postgresql-client

cd /vagrant/backend

# Generate .env here rather than committing it to git. This is a throwaway
# local dev credential, not a real secret, so it's safe to bake into
# provisioning for reproducibility.
cat > .env << 'ENVEOF'
DATABASE_URL=postgresql://sentinel:sentinel_pw@192.168.56.11:5432/sentinel_db
PORT=5000
ENVEOF

npm install

# Apply schema. Safe to re-run: schema.sql uses CREATE TABLE IF NOT EXISTS.
PGPASSWORD=sentinel_pw psql -h 192.168.56.11 -U sentinel -d sentinel_db -f sql/schema.sql

# Only seed if the assets table is empty, so re-provisioning an already
# running VM doesn't insert a second batch of demo data on top.
ASSET_COUNT=$(PGPASSWORD=sentinel_pw psql -h 192.168.56.11 -U sentinel -d sentinel_db -t -c "SELECT count(*) FROM assets;" | tr -d '[:space:]')
if [ "$ASSET_COUNT" = "0" ]; then
  PGPASSWORD=sentinel_pw psql -h 192.168.56.11 -U sentinel -d sentinel_db -f sql/seed.sql
fi

# Run the backend as a systemd service so it keeps running after this
# provisioning script finishes, and restarts automatically if it crashes.
cat > /etc/systemd/system/sentinel-backend.service << 'SERVICEEOF'
[Unit]
Description=Sentinel backend API
After=network.target

[Service]
Type=simple
WorkingDirectory=/vagrant/backend
ExecStart=/usr/bin/node /vagrant/backend/index.js
Restart=on-failure
User=vagrant
EnvironmentFile=/vagrant/backend/.env

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable sentinel-backend
systemctl restart sentinel-backend