#!/usr/bin/env bash
# Task 2: export -> create target -> import -> verify.   The SOURCE is never modified (it is the rollback).
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ts=$(date +%Y%m%d-%H%M%S); dump="migration/backups/cloudnotes-source-${ts}.sql"

echo "[1/4] EXPORT  pg_dump from source (db) -> ${dump}"
docker compose exec -T db pg_dump -U cloudnotes -d cloudnotes --no-owner --no-privileges > "$dump"
echo "      $(wc -l < "$dump" | tr -d ' ') lines, $(du -h "$dump" | cut -f1)"

echo "[2/4] CREATE TARGET  fresh PostgreSQL 17 (db-target)"
docker compose up -d --wait db-target >/dev/null 2>&1 || docker compose up -d db-target
for i in $(seq 1 30); do docker compose exec -T db-target pg_isready -U cloudnotes >/dev/null 2>&1 && break; sleep 1; done
existing=$(q db-target "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'")
if [[ "$existing" != "0" ]]; then
  if [[ "${FORCE:-0}" == "1" ]]; then q db-target "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" >/dev/null
  else echo "      target already has tables. Re-run with FORCE=1 to wipe the TARGET and migrate again."; exit 1; fi
fi
echo "      $(q db-target "SELECT split_part(version(), ' on ', 1)") is empty and ready"

echo "[3/4] IMPORT  restore dump into target"
docker compose exec -T db-target psql -U cloudnotes -d cloudnotes -q -v ON_ERROR_STOP=1 < "$dump" >/dev/null
echo "      done"

echo "[4/4] VERIFY  source vs target"
line
sum="SELECT md5(coalesce(string_agg(id||'|'||title||'|'||body||'|'||coalesce(filename,'')||'|'||created_at, ',' ORDER BY id),'')) FROM notes"
printf '  %-20s %-14s %-14s %s\n' "CHECK" "SOURCE (db)" "TARGET (17)" "RESULT"
ok=1
cmp() { local name="$1" a="$2" b="$3"; local r="MATCH"; [[ "$a" == "$b" ]] || { r="MISMATCH"; ok=0; }
        printf '  %-20s %-14s %-14s %s\n' "$name" "${a:0:12}" "${b:0:12}" "$r"; }
cmp "tables"            "$(q db "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'")" "$(q db-target "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'")"
cmp "notes rows"        "$(q db "SELECT count(*) FROM notes")"             "$(q db-target "SELECT count(*) FROM notes")"
cmp "schema_migrations" "$(q db "SELECT count(*) FROM schema_migrations")" "$(q db-target "SELECT count(*) FROM schema_migrations")"
cmp "max note id"       "$(q db "SELECT coalesce(max(id),0) FROM notes")"  "$(q db-target "SELECT coalesce(max(id),0) FROM notes")"
cmp "data checksum(md5)" "$(q db "$sum")"                                   "$(q db-target "$sum")"
line
echo "Migrated tables in target:"
qt db-target "\dt" | sed 's/^/  /'
[[ $ok == 1 ]] && echo "RESULT: migration verified, all checks MATCH. Source left untouched (rollback)." || { echo "RESULT: MISMATCH, do NOT repoint the app."; exit 1; }
