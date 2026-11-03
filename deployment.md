# CloudNotes Deployment (Linux server + systemd + PostgreSQL)

This document covers how CloudNotes moves from `python app.py` on a laptop to an
**always-on service** on a Linux server: managed by systemd, reachable on port
5000, and storing its data in PostgreSQL.

> **Environment used:** Ubuntu 24.04 LTS on _<VirtualBox / UTM / WSL2 — fill in yours>_
> **Server IP:** _<e.g. 192.168.56.10, or localhost via port-forwarding>_

---

## 1. What changed in the app

| Before (v1, laptop) | After (deployed) |
|---|---|
| `python app.py` (Flask dev server) | `gunicorn --workers 2 --bind 0.0.0.0:5000 app:app` |
| Bound to `127.0.0.1` | Bound to `0.0.0.0` (all interfaces) |
| SQLite file `database/cloudnotes.db` | PostgreSQL database `cloudnotes` |
| Paths/settings hardcoded in `app.py` | `DATABASE_URL`, `SECRET_KEY`, `UPLOAD_FOLDER` read from `.env` |
| Schema created on first request (`before_first_request`, removed in Flask 2.3) | Versioned SQL migrations in `migrations/`, applied by `migrate.py` |
| Dies when the terminal closes | systemd service: starts on boot, restarts on crash |
| No health check | `GET /health` checks the app **and** the DB connection |

## 2. Repository files for the deployment

| File | Purpose |
|---|---|
| `deploy/setup.sh` | One-shot setup script (packages, user, venv, PostgreSQL, migrations, service, firewall) |
| `deploy/cloudnotes.service` | systemd unit file |
| `.env.example` | Placeholder config. Copy it to `.env`; **`.env` is git-ignored** |
| `migrate.py` + `migrations/001_create_notes.sql` | Creates the schema in PostgreSQL |
| `Dockerfile` + `docker-compose.yml` | Alternative container path (`restart: always`) |
| `cloud-mapping.md` | How each piece maps to Compute Engine |
| `docs/evidence/` | Screenshots and logs proving the deployment works |

---

## 3. Set up the Linux server

### Option A: VirtualBox / UTM VM (recommended)
1. Download the Ubuntu Server 24.04 ISO and create a VM (2 vCPU, 2 GB RAM, 20 GB disk).
2. Networking, pick one:
   - **NAT + port forwarding:** Settings → Network → Advanced → Port Forwarding:
     `Host 127.0.0.1:5000 → Guest :5000` (and `2222 → 22` for SSH). Browser URL: `http://localhost:5000`.
   - **Bridged adapter** (or a UTM "Shared Network"): the VM gets its own LAN IP (`ip -4 addr`). Browser URL: `http://<vm-ip>:5000`.
3. Install OpenSSH during setup so you can `ssh -p 2222 user@localhost`.

### Option B: WSL2 Ubuntu
```bash
# In PowerShell (Windows)
wsl --install -d Ubuntu-24.04
```
Enable systemd inside WSL by adding this to `/etc/wsl.conf`:
```ini
[boot]
systemd=true
```
Then run `wsl --shutdown` in PowerShell and reopen Ubuntu. WSL2 forwards `localhost:5000` to Windows automatically.

### Option C: Docker
See [section 8](#8-alternative-docker-no-systemd).

---

## 4. Install and run (exact commands)

### Quick path: the setup script
```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/AditiV05/cloudnotes-v1.git
cd cloudnotes-v1
sudo bash deploy/setup.sh
```

### Manual path (what the script does, step by step)
```bash
# 1. System packages
sudo apt-get update
sudo apt-get install -y python3 python3-venv python3-pip postgresql postgresql-contrib ufw git

# 2. Dedicated, unprivileged service user + code
sudo useradd --create-home --shell /bin/bash cloudnotes
sudo -iu cloudnotes
git clone https://github.com/AditiV05/cloudnotes-v1.git cloudnotes
cd cloudnotes

# 3. Python dependencies in a virtualenv
python3 -m venv venv
venv/bin/pip install -r requirements.txt
exit   # back to your sudo user

# 4. PostgreSQL database + user
sudo systemctl enable --now postgresql
sudo -u postgres psql -c "CREATE ROLE cloudnotes LOGIN PASSWORD '<strong-password>';"
sudo -u postgres createdb -O cloudnotes cloudnotes

# 5. Environment variables (real values, never committed)
sudo -iu cloudnotes
cd cloudnotes
cp .env.example .env
nano .env          # set DATABASE_URL, SECRET_KEY, UPLOAD_FOLDER
chmod 600 .env

# 6. Migrations (create the tables in PostgreSQL)
venv/bin/python migrate.py
exit

# 7. Install and start the systemd service
sudo cp /home/cloudnotes/cloudnotes/deploy/cloudnotes.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now cloudnotes
sudo systemctl status cloudnotes

# 8. Open the port on the OS firewall
sudo ufw allow OpenSSH
sudo ufw allow 5000/tcp
sudo ufw enable
sudo ufw status
```

---

## 5. Managed service: proof it starts on boot and restarts on crash

The unit file (`deploy/cloudnotes.service`) has two key lines:

- `Restart=always` (+ `RestartSec=3`): systemd restarts gunicorn whenever it exits.
- `WantedBy=multi-user.target` + `systemctl enable`: systemd starts it on every boot.

### Crash test
```bash
systemctl show -p MainPID cloudnotes          # note the PID, e.g. MainPID=1234
sudo kill -9 $(systemctl show -p MainPID --value cloudnotes)
sleep 4
systemctl status cloudnotes                   # active (running) again, NEW PID
journalctl -u cloudnotes -n 20 --no-pager     # shows "Scheduled restart job"
```

### Reboot test
```bash
systemctl is-enabled cloudnotes               # -> enabled
sudo reboot
# ...after reconnecting, without starting anything by hand:
systemctl status cloudnotes                   # active (running)
curl http://localhost:5000/health
```

### Logout test
Close the SSH session / terminal and open `http://<server>:5000/notes` from the host. It still loads, because the process belongs to systemd, not to your shell.

---

## 6. Reachability and the request path

```bash
# On the server
curl http://localhost:5000/health     # {"database":"postgresql","pid":...,"status":"ok"}
ss -tlnp | grep 5000                  # must show 0.0.0.0:5000, NOT 127.0.0.1:5000
sudo ufw status                       # 5000/tcp ALLOW

# On the host machine
curl http://<server-ip-or-localhost>:5000/health
# Browser: http://<server-ip-or-localhost>:5000/notes
```

### The request path
```
Your browser (host)
   │  http://<vm-ip>:5000/notes   (or localhost:5000 with port forwarding)
   ▼
Host / VM network  (VirtualBox NAT port-forward 5000→5000, bridged LAN, or WSL localhost relay)
   │
   ▼
OS firewall  (ufw: 5000/tcp ALLOW)  ← most common silent failure point
   │
   ▼
Linux server  (Ubuntu, the kernel hands the TCP connection to whoever listens on :5000)
   │
   ▼
gunicorn on 0.0.0.0:5000  (managed by systemd)  →  Flask app  →  PostgreSQL on localhost:5432
```

In my own words: the browser sends an HTTP request to the VM's address on port
5000. The host's virtual network carries it into the VM, either through a
port-forward rule or because the VM sits on the LAN. Inside the VM, the ufw
firewall checks whether port 5000 is allowed. If it is, the kernel passes the
connection to gunicorn, which is listening on every interface (`0.0.0.0`).
gunicorn hands the request to a Flask worker, Flask queries PostgreSQL over
localhost, and the response goes back along the same path.

### Debugging checklist (one hop at a time)
| Symptom | Likely hop | Check |
|---|---|---|
| `curl localhost:5000` fails **on the server** | App / service | `systemctl status cloudnotes`, `journalctl -u cloudnotes` |
| Works on server, fails from host | Bind address | `ss -tlnp \| grep 5000` shows `127.0.0.1`? Must be `0.0.0.0` |
| Works on server, fails from host, bind is fine | Firewall / port | `sudo ufw status`; VirtualBox port-forward rule |
| `/health` returns 503 | Database | `systemctl status postgresql`, `DATABASE_URL` in `.env` |

---

## 7. PostgreSQL and the persistence test

```bash
# Add a note through the API (or the /notes page in the browser)
curl -X POST -F title="Persistence test" -F body="Written before restart" http://localhost:5000/api/notes

# Restart the app
sudo systemctl restart cloudnotes
curl http://localhost:5000/api/notes          # the note is still there

# Stronger test: reboot the whole machine
sudo reboot
curl http://localhost:5000/api/notes          # still there

# Look at it directly in the database
sudo -u postgres psql cloudnotes -c "SELECT id, title, created_at FROM notes;"
```

The note survives because it is stored in PostgreSQL (on disk under
`/var/lib/postgresql`), not in the gunicorn process. See
`docs/evidence/local-test-log.txt` for a recorded run of this test.

---

## 8. Alternative: Docker (no systemd)

> **Mac users:** macOS uses port 5000 for *AirPlay Receiver*. If you get "address already in use",
> turn it off in System Settings → General → AirDrop & Handoff → AirPlay Receiver.
> In Docker Desktop → Settings → General, tick **"Start Docker Desktop when you sign in"** so the app comes back after a reboot.

```bash
cp .env.example .env      # set SECRET_KEY and POSTGRES_PASSWORD
docker compose up -d --build
docker compose ps
curl http://localhost:5000/health
# Persistence: add a note, restart, check it is still there, and look in PostgreSQL directly
docker compose restart app
curl http://localhost:5000/api/notes
docker compose exec db psql -U cloudnotes -c "SELECT id, title FROM notes;"

# Crash test: kill gunicorn (PID 1) inside the container; Docker restarts it (restart: always).
# Works on Mac, Windows and Linux. (`docker stop` would count as a manual stop and NOT restart.)
docker inspect -f '{{.RestartCount}}' $(docker compose ps -q app)   # e.g. 0
docker compose exec app sh -c 'kill 1'
sleep 5
docker compose ps                                                     # app is Up again ("Up 3 seconds")
docker inspect -f '{{.RestartCount}}' $(docker compose ps -q app)   # now 1

# Reboot test: Docker's own service is enabled on boot, and restart: always containers come back with it
sudo systemctl is-enabled docker     # Linux only. On Mac/Windows: restart the computer, then `docker compose ps`
```
PostgreSQL data lives in the `pgdata` named volume, so it survives container restarts.

---

## 9. Security notes
- `.env` holds the real DB password and `SECRET_KEY`. It is in `.gitignore` and has `chmod 600`.
- The app runs as the unprivileged `cloudnotes` user, not root.
- PostgreSQL only listens on `localhost` (the default), so port 5432 is **not** opened in the firewall.
- Next steps (later modules): nginx in front of gunicorn, HTTPS, tighter firewall source ranges.
