#!/bin/bash
#Everytime an instance boots, this code fetches the latest code form github, installs the dependencies and starts serving the app automatically.

set -euo pipefail

#Refreshes ubuntus package list, adds nodesSource repo then installs node.js 20 & git
apt-get update -y
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs git

#Pulls the actual apps code straight from github onto the instnace into /home/ubuntu/app then moves into the frontend folder

cd /home/ubuntu
git clone https://github.com/MatthewWallbridge/Sentinal.git app
cd app/frontend

#This writes a .env file telling the frontend where the backend api livs ("${backend_ip}") using a terraform placeholder.
cat > .env << ENVEOF
VITE_API_BASE=http://${backend_ip}:5000/api
ENVEOF

#installs the frontend dependiences (React, vite, etc) from the package.json
#npm install itself still runs as root here, so it's important this comes
#BEFORE the chown below - otherwise node_modules/ (created by this command)
#would end up root-owned again, undoing the fix.
npm install

#the systemd service below runs the app as the non-root "ubuntu" user, but
#everything above (git clone, npm install) ran as root, so ubuntu doesn't
#own any of it yet. Fix ownership of the whole tree - including node_modules,
#which vite needs write access to for its dependency cache - after
#installing, not before, so nothing created by npm install is missed.
chown -R ubuntu:ubuntu /home/ubuntu/app

#this writes a systemd service def, which will make the app run persistently as a background service 
cat > /etc/systemd/system/sentinel-frontend.service << SERVICEEOF
[Unit]
Description=Sentinel frontend
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/ubuntu/app/frontend
ExecStart=/usr/bin/npm run dev
Restart=on-failure
User=ubuntu

[Install]
WantedBy=multi-user.target
SERVICEEOF

#tells systemd to reload its configuration so it notices the new service file
systemctl daemon-reload
systemctl enable sentinel-frontend
systemctl restart sentinel-frontend

