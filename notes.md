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
  version is older and Prisma (at the time) needed a current one.

- Dropped Prisma ORM entirely in favour of the plain `pg` library plus
  hand-written SQL files (see the Prisma saga in the debugging log below
  for the full story of why). Alternative considered: keep fighting
  Prisma by pinning an older major version (5.x). Rejected because the
  assignment is marked on deployment reproducibility, not ORM
  sophistication, and a tool that breaks in version-specific ways inside
  a VirtualBox shared folder is a direct risk to the "no unexplained
  repairs" requirement. Plain SQL has no CLI, no symlinks, no config
  files, and is trivial to run non-interactively during provisioning.

## Debugging log

- [2026-08-01] db VM: after creating the `sentinel` Postgres user and
  running `psql -h 192.168.56.11 -U sentinel -d sentinel_db` from
  backend, got "password authentication failed for user sentinel".
  Network and pg_hba.conf rule were both fine (ping worked, connection
  reached Postgres). Root cause not fully confirmed, most likely the
  password wasn't set as expected on the first CREATE USER, or was
  mistyped at the prompt (it's hidden while typing). Fixed by re-running
  `ALTER USER sentinel WITH PASSWORD 'sentinel_pw';` directly on db,
  then it connected fine.

- [2026-08-01] backend VM: the Prisma saga, in order.

  1. Running `npm install -D prisma` inside /vagrant/backend failed
     repeatedly with `EPROTO: protocol error, symlink ...
     node_modules/.bin/pglite-server`. Retried once, same result, so
     ruled out a transient glitch. Root cause: VirtualBox's shared
     folder driver (vboxsf), which is what makes /vagrant visible on
     both host and guest, does not reliably support symlinks, especially
     from a Windows host. The prisma CLI package pulls in a nested
     dependency (@electric-sql/pglite-socket) that needs to create a
     symlinked binary in node_modules/.bin, and that's what fails.
     Note: express, cors, dotenv, and @prisma/client all installed fine,
     only packages needing bin symlinks were affected.
     First fix: installed the prisma CLI globally instead
     (`sudo npm install -g prisma`), since a global install lives on the
     VM's own disk, not the shared folder.

  2. `npx prisma init` then generated a `prisma.config.ts` file that
     does `import { defineConfig } from "prisma/config"`. This import
     needs the `prisma` package to exist in the project's own
     node_modules, but it was only installed globally (see above), so
     running any prisma command failed with "Cannot find module
     'prisma/config'". Since the file's settings matched Prisma's own
     defaults anyway (schema path, migrations path), deleted it as
     redundant.

  3. Deleting the config file then exposed a bigger issue: Prisma 7
     no longer supports `url = env("DATABASE_URL")` directly in
     schema.prisma for Migrate, it now requires the connection string
     to come through prisma.config.ts (error code P1012). This is a
     genuine breaking change in Prisma 7's architecture, not a config
     mistake, confirmed by restoring the config file and watching it
     fail on the missing local package exactly as predicted.

  4. Considered pinning to an older Prisma version (5.22.0) that
     predates both the shadow-config requirement and the pglite
     dependency causing the symlink bug. Ultimately decided this was
     two compounding environment-specific problems stacked on top of
     each other, and not worth the ongoing risk for a project graded on
     reproducible deployment. Dropped Prisma completely.

  5. Replaced it with the `pg` library and hand-written SQL: created
     backend/sql/schema.sql (assets, vulnerabilities, notes tables with
     IF NOT EXISTS for safe re-runs) and backend/sql/seed.sql (20 assets,
     40 vulnerabilities, 13 notes, using generate_series so it isn't
     20 manual INSERT statements). Verified both by running them by hand
     via psql before wiring them into any provisioning script.

- [2026-08-01] backend VM: after switching to `pg`, the `/api/dashboard`
  route failed with `ECONNREFUSED 127.0.0.1:5432`, meaning it was trying
  to reach Postgres on localhost instead of the db VM's private IP. The
  giveaway was the server's own startup log: `injected env (0) from
  .env`, meaning dotenv loaded zero variables. Checked with `cat -A .env`
  and found the file didn't exist at all, it had likely been deleted by
  accident during the Prisma cleanup step. Recreated backend/.env with
  DATABASE_URL and PORT, restarted the server, and the dashboard endpoint
  then returned real seeded data end to end (host -> backend VM -> db VM).

- [2026-08-01] backend VM: after moving the backend to run as a systemd
  service (sentinel-backend) instead of manual `npm start`, saw the same
  `injected env (0) from .env` log line again, but this time it was
  harmless: systemd's EnvironmentFile directive loads DATABASE_URL and
  PORT into the process before Node starts, so dotenv correctly declines
  to overwrite variables that already exist and reports 0 new ones. Same
  log line, two completely different causes (once a real bug, once
  expected behaviour), worth remembering when reading logs.

- [2026-08-19] backend VM: `vagrant up` on a fresh terminal session got
  through db fine, then failed on backend with "Timed out while waiting
  for the machine to boot" (default 300s boot_timeout). Confusing because
  `vagrant global-status` showed the VM as "running" straight after, and
  the forwarded SSH port (2200) was accepting TCP connections, so the VM
  wasn't actually dead, something was stopping the SSH handshake itself
  from completing in time. Root cause, once traced: `.vagrant/` (Vagrant's
  own per-machine runtime state: VirtualBox VM IDs, the generated SSH
  private key for each VM, box metadata) had been committed to git the
  whole time, and there was no `.gitignore` at all in the repo. That
  directory is meant to be host-specific and regenerated on every machine;
  committing it meant my own local copy could drift out of sync with what
  VirtualBox actually had registered (`git status` was independently
  showing the backend VM's `private_key` file as deleted), which was
  enough to stall the SSH key exchange past the timeout. This would have
  been worse on a fresh clone: whoever cloned it would inherit VM IDs and
  private keys tied to VirtualBox machines that only exist on my computer,
  not theirs.
  Fix: `git rm -r --cached .vagrant` to untrack it, added a `.gitignore`
  with `.vagrant/` in it so it can never be committed again. Also bumped
  `config.vm.boot_timeout` to 600s in the Vagrantfile (from the 300s
  default) and pinned each VM to 1024MB/1 CPU via a `virtualbox` provider
  block, as a safety margin in case a marker's machine is slower than
  mine. Verified by destroying both VMs, deleting the local `.vagrant/`
  folder entirely (this exactly reproduces what a fresh `git clone` looks
  like), then running `vagrant up` from nothing: all three VMs came up
  cleanly, and even hit a couple of transient "Connection reset. Retrying..."
  SSH blips along the way without failing, which the old 300s timeout
  might not have survived either.

- [2026-08-19] frontend VM: `frontend.sh` only ever installed Node.js, it
  never ran `npm install` for the actual app or started anything on port
  3000, so `vagrant up` alone left the frontend VM booted but serving
  nothing, you'd have to SSH in and start it by hand every time. Fixed by
  extending frontend.sh to run `npm install` in /vagrant/frontend and
  register a systemd service (sentinel-frontend) running `npm run dev`,
  matching the pattern already used for the backend. Confirmed with
  `curl localhost:3000` returning HTTP 200 after a full `vagrant up`, and
  that editing a file on the host reflects live in the browser without
  any manual step, thanks to `usePolling: true` already being set in
  vite.config.js (needed because VirtualBox's shared folder driver
  doesn't reliably deliver filesystem-change notifications to the guest).

## Reproducibility checks

- [2026-08-01] Ran a full `vagrant destroy -f` followed by `vagrant up`
  from a clean state, no manual steps beforehand. All three VMs (db,
  backend, frontend) came up successfully, confirmed with `vagrant status`
  showing all three as running. The backend's systemd service
  (sentinel-backend) was active and serving requests automatically,
  without me manually running `npm start`. Confirmed via a GET request
  to http://localhost:5000/api/dashboard (through the forwarded port)
  that it returned the correct seeded data (20 assets, vulnerabilities
  split 20 High / 20 Medium and 20 Open / 20 Fixed). This is the core
  evidence that the whole system, provisioning, schema, seed data, and
  the running service, rebuilds itself from nothing with a single
  `vagrant up` command and no manual repairs.

## Data volume estimates (fill in once backend/frontend provisioning exists)

- Clean build downloads: TODO (Ubuntu box size, apt packages, npm packages)
- Repeat build downloads: TODO (box is cached, only apt/npm deltas)

## Changes made during development (for modification/redevelopment section)

- TODO: once app exists, make one real change, note the commit hash here
  and how you verified it afterward.

## AI use log

- Used Claude to help scaffold the Vagrantfile structure, provisioning
  script syntax, and to talk through several debugging problems (Postgres
  auth failure, the Prisma/vboxsf symlink issue, Prisma 7's config
  requirement, and the missing .env file).

- [2026-08-19] Used Claude to diagnose the backend boot-timeout issue
  above: it traced the failure to `.vagrant/` being committed to git,
  untracked it, added the missing `.gitignore`, adjusted the Vagrantfile
  timeout/resource settings.