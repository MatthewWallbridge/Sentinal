#!/usr/bin/env bash
set -euo pipefail

apt-get update
apt-get install -y postgresql postgresql-contrib

# Let Postgres listen on all interfaces (the private network included)
sed -i "s/^#listen_addresses.*/listen_addresses = '*'/" /etc/postgresql/14/main/postgresql.conf

# Allow the backend VM's subnet to connect with a password
echo "host    all             all             192.168.56.0/24         md5" >> /etc/postgresql/14/main/pg_hba.conf

systemctl restart postgresql

# Create the app database and user (idempotent-ish: ignore error if already exists)
sudo -u postgres psql -c "CREATE USER sentinel WITH PASSWORD 'sentinel_pw';" || true
sudo -u postgres psql -c "CREATE DATABASE sentinel_db OWNER sentinel;" || true