# CloudNotes Database Migration (LU 2.7, Part A)

**Migration:** PostgreSQL 16 (`db`) → PostgreSQL 17 (`db-target`), both local Docker containers on the private `data` network.
**Method:** SQL dump and restore (`pg_dump` → `psql`). The source is never modified, so it stays available as the rollback.
The original SQLite file from v1 had 0 notes; the real data has lived in PostgreSQL since LU 2.2.

| Step | Script | What it does |
|---|---|---|
| 0. Prepare | `migration/00-prepare.sh` | Points `DATABASE_URL` in `.env` at the source (`db`) and generates `TARGET_DB_PASSWORD` |
| 1. Analyze source | `migration/01-analyze-source.sh` | DB type/version, size, tables, row counts, sample rows (read-only) |
| 2. Migrate | `migration/02-migrate.sh` | **Export** (`pg_dump`) → **create target** (PostgreSQL 17) → **import** → **verify** (tables, row counts, max id, md5 checksum of all rows) |
| 3. Repoint | `migration/03-repoint.sh` | Changes only `DATABASE_URL` in `.env` to `db-target`, restarts the app, shows config with passwords masked |
| 4. Verify app | `migration/04-verify-app.sh` | Health check (shows `db_host` + `server_version`), reads migrated notes, creates a new note, confirms it landed in the target |
| Rollback | `migration/03-repoint.sh source` | Points the app back at the untouched source in one command |

The order matters: the app is repointed **only after** the import is verified, and the source is **never deleted** until the new database is proven.

```bash
cp .env.example .env              # once; set POSTGRES_PASSWORD and SECRET_KEY
migration/00-prepare.sh
docker compose up -d --build
migration/01-analyze-source.sh
migration/02-migrate.sh
migration/03-repoint.sh
migration/04-verify-app.sh
```

Dumps are written to `migration/backups/` and are git-ignored because they contain real data.
See [`cloud-sql-design.md`](cloud-sql-design.md) for Part B.
