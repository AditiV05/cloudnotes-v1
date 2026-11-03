# CloudNotes

A small Flask note-taking app (notes + file attachments) backed by PostgreSQL.

## Run locally (dev)
```bash
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env        # set DATABASE_URL to a PostgreSQL database
python migrate.py
python app.py               # http://localhost:5000
```

## Deploy
- [`deployment.md`](deployment.md): Linux server setup, systemd service, firewall, PostgreSQL, request path
- [`cloud-mapping.md`](cloud-mapping.md): how the local deployment maps to Google Compute Engine
- [`deploy/`](deploy/): `setup.sh` and the `cloudnotes.service` systemd unit
- `Dockerfile` / `docker-compose.yml`: container alternative
- [`architecture/`](architecture/): Module 1 cloud architecture proposal
- [`network-security/`](network-security/): LU 2.4 tiered network (nginx web tier, private app + db), firewall rules, connectivity tests, GCP firewall mapping
- [`migration/`](migration/): LU 2.7 PostgreSQL 16 → 17 migration scripts (analyze, migrate + verify, repoint, verify app) and the [Cloud SQL design](migration/cloud-sql-design.md)
- [`review/`](review/): LU 2.11 production architecture review (two-layer diagram, four-lens self-review, ADRs)
