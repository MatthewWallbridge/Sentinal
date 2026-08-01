#!/usr/bin/env bash
set -euo pipefail

# Install Node.js 20.x LTS via NodeSource's setup script
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
apt-get install -y nodejs

echo "Node version:"
node --version
echo "npm version:"
npm --version