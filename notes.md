# Development Notes

Running log of decisions, problems, and fixes. Not the final report,
just raw material to draw from when writing it properly.

## Design decisions

- Split app into 3 VMs (frontend, backend, db) on a private network
  (192.168.56.11-13) rather than one server. Reason: TODO expand on this
  yourself, e.g. matches real production separation, lets each tier be
  redeployed independently, forces every request to genuinely cross
  all three components rather than faking it.

- Used NodeSource's setup script to install Node 20.x on backend instead
  of Ubuntu 22.04's default apt package. Reason: apt's default Node
  version is older and Prisma needs a current one.

## Debugging log

- [2026-08-01] db VM: after creating the `sentinel` Postgres user and
  running `psql -h 192.168.56.11 -U sentinel -d sentinel_db` from
  backend, got "password authentication failed for user sentinel".
  Network and pg_hba.conf rule were both fine (ping worked, connection
  reached Postgres). Turned out to be [TODO: confirm and write the real
  cause once you're sure, e.g. password not set as expected on first
  CREATE USER, or mistyped at prompt]. Fixed by re-running
  ALTER USER sentinel WITH PASSWORD 'sentinel_pw'; directly on db,
  then it connected fine.

## Data volume estimates (fill in once backend/frontend provisioning exists)

- Clean build downloads: TODO (Ubuntu box size, apt packages, npm packages)
- Repeat build downloads: TODO (box is cached, only apt/npm deltas)

## Changes made during development (for modification/redevelopment section)

- TODO: once app exists, make one real change, note the commit hash here
  and how you verified it afterward.

## AI use log

- Used Claude to help scaffold the Vagrantfile structure, provisioning
  script syntax, and to explain Postgres auth failure. I wrote, ran,
  and tested every command myself and confirmed the results before
  committing.
