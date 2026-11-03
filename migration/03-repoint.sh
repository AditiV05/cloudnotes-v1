#!/usr/bin/env bash
# Task 3: repoint CloudNotes to the migrated database by changing ONE environment variable.
#   migration/03-repoint.sh          -> point at db-target (PostgreSQL 17)
#   migration/03-repoint.sh source   -> ROLLBACK: point back at db (PostgreSQL 16)
set -euo pipefail
source "$(dirname "$0")/lib.sh"
if [[ "${1:-target}" == "source" ]]; then host=db; pw=$(envval POSTGRES_PASSWORD); else host=db-target; pw=$(envval TARGET_DB_PASSWORD); fi
perl -pi -e "s#^DATABASE_URL=.*#DATABASE_URL=postgresql://cloudnotes:${pw}\@${host}:5432/cloudnotes#" .env
docker compose up -d app >/dev/null 2>&1
for i in $(seq 1 20); do curl -sf http://localhost/health >/dev/null 2>&1 && break; sleep 1; done
echo "UPDATED APPLICATION CONFIGURATION (passwords masked)"
line
echo "1) .env  (git-ignored, holds the real secret):"
grep -E '^DATABASE_URL=' .env | mask | sed 's/^/   /'
echo "2) docker-compose.yml  (passes the variable through, no credentials):"
grep -n 'DATABASE_URL:' docker-compose.yml | sed 's/^/   /'
echo "3) Inside the running app container:"
docker compose exec -T app printenv DATABASE_URL | mask | sed 's/^/   DATABASE_URL=/'
echo "4) Code reads it from the environment (utils/helpers.py):"
grep -n 'os.environ.get("DATABASE_URL")' utils/helpers.py | sed 's/^/   /'
echo "5) Hardcoded credentials in code:"
hits=$(grep -rnE 'postgresql://[^:"]+:[^@"$*]+@' --include='*.py' . | grep -v CHANGE_ME || true)
[[ -z "$hits" ]] && echo "   none found (grep for postgresql://user:pass@ in *.py)" || echo "$hits"
echo "6) App health:"
echo "   $(curl -s http://localhost/health)"
line
