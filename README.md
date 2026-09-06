# Sentinel

Sentinel is a small web-based Cyber Asset & Vulnerability Management platform. It lets an administrator track IT assets (servers, laptops, network devices), record known vulnerabilities against those assets, assign severity levels, and monitor overall security posture through a dashboard.

## Architecture

The application runs across three virtual machines on a private network, each with a distinct responsibility:

| VM | IP | Role |
|---|---|---|
| `db` | 192.168.56.11 | PostgreSQL 14. Stores all application data (assets, vulnerabilities, notes). Has no application logic of its own. |
| `backend` | 192.168.56.12 | Node.js/Express REST API (port 5000). The only component that talks to the database. Validates input, runs SQL queries via the `pg` library, and serves JSON to the frontend. |
| `frontend` | 192.168.56.13 | React (Vite) single-page app (port 3000). Renders the UI and calls the backend's API. Has no direct database access and no business logic. |

Every user action (viewing the dashboard, adding an asset, changing a vulnerability's status) genuinely passes through all three machines: the browser talks to `frontend`, which is just static files; the page's own JavaScript then calls `backend` directly; `backend` queries `db` and returns the result.

Ports 3000 (frontend) and 5000 (backend API) are forwarded to the host machine, so both are reachable at `localhost` once the VMs are running.

## Host requirements

- A computer capable of running VirtualBox (tested on Windows).
- [VirtualBox](https://www.virtualbox.org/) 7.2.x (developed and tested with 7.2.10).
- [Vagrant](https://www.vagrantup.com/) 2.4.x (developed and tested with 2.4.9).
- Around 3GB of free RAM for the three VMs, plus a few GB of disk space for the Ubuntu box image.

No other tools are required on the host. Node.js, PostgreSQL, and all application dependencies are installed automatically inside the VMs during provisioning.

## Deploy

```bash
git clone <repository-url> sentinel
cd sentinel
vagrant up
```

This single command creates and configures all three VMs from scratch:

- `db`: installs PostgreSQL, creates the `sentinel` user and `sentinel_db` database, and configures it to accept connections from the private network only.
- `backend`: installs Node.js 20.x, installs npm dependencies, applies the SQL schema, seeds demo data (20 assets, 40 vulnerabilities, 13 investigation notes) if the database is empty, and runs the API as a systemd service (`sentinel-backend`) so it starts automatically and restarts on failure.
- `frontend`: installs Node.js 20.x, installs npm dependencies, and runs the dev server as a systemd service (`sentinel-frontend`).

No manual steps or configuration choices are needed during or after this command.

## Verify

```bash
./verify.sh
```

This checks that all three VMs are running, that the frontend and backend are reachable on their forwarded ports, and that the database contains the expected seeded data, confirming a genuine end-to-end interaction across all three machines.

## Access the application

Once deployed, open:

- **http://localhost:3000** — the Sentinel dashboard
- **http://localhost:5000/api/dashboard** — the backend API directly, if needed

## Remove everything

```bash
vagrant destroy -f
```

This deletes all three VMs and their disks. Nothing else on the host is affected.

## Making changes

Application source files (`backend/`, `frontend/`) can be edited directly on the host, they're synced into the VMs automatically. The frontend picks up changes live (Vite's dev server watches for edits). Backend changes require the service to be restarted:

```bash
vagrant ssh backend
sudo systemctl restart sentinel-backend
```

To fully re-run a VM's provisioning from scratch (e.g. after changing a provisioning script):

```bash
vagrant provision <db|backend|frontend>
```

## Repository structure
Vagrantfile # Defines the 3 VMs, networking, and provisioning
provisioning/
db.sh # Installs and configures PostgreSQL
backend.sh # Installs Node.js, deps, applies schema/seed, runs API as a service
frontend.sh # Installs Node.js, deps, runs the dev server as a service
backend/
index.js # Express API
sql/schema.sql # Table definitions
sql/seed.sql # Demo data
package.json
frontend/
src/App.jsx # React UI
package.json
verify.sh # Automated deployment check
notes.md # Development log: decisions, debugging, reproducibility checks.
