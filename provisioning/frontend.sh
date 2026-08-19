#!/usr/bin/env bash
set -euo pipefail

curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
apt-get install -y nodejs

echo "Node version:"
node --version
echo "npm version:"
npm --version

cd /vagrant/frontend
npm install

# Run the frontend dev server as a systemd service so it keeps running after
# this provisioning script finishes, and restarts automatically if it crashes.
cat > /etc/systemd/system/sentinel-frontend.service << 'SERVICEEOF'
[Unit]
Description=Sentinel frontend dev server
After=network.target

[Service]
Type=simple
WorkingDirectory=/vagrant/frontend
ExecStart=/usr/bin/npm run dev
Restart=on-failure
User=vagrant

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable sentinel-frontend
systemctl restart sentinel-frontend