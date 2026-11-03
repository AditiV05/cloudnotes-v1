#!/usr/bin/env bash
# One-time: make sure .env points the app at the SOURCE database (db) and has a password for the TARGET.
source "$(dirname "$0")/lib.sh"
[[ -f .env ]] || { echo "No .env found. Run: cp .env.example .env  (then edit the CHANGE_ME values)"; exit 1; }
pw=$(envval POSTGRES_PASSWORD)
[[ -n "$pw" && "$pw" != CHANGE_ME* ]] || { echo "Set POSTGRES_PASSWORD in .env first."; exit 1; }
url="postgresql://cloudnotes:${pw}@db:5432/cloudnotes"
grep -vE '^DATABASE_URL=' .env > .env.tmp && mv .env.tmp .env
echo "DATABASE_URL=${url}" >> .env
if ! grep -qE '^TARGET_DB_PASSWORD=' .env || [[ "$(envval TARGET_DB_PASSWORD)" == CHANGE_ME* ]]; then
  tpw=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)
  grep -vE '^TARGET_DB_PASSWORD=' .env > .env.tmp && mv .env.tmp .env
  echo "TARGET_DB_PASSWORD=${tpw}" >> .env
fi
chmod 600 .env
echo "Prepared .env:"
grep -E '^(DATABASE_URL|TARGET_DB_PASSWORD)=' .env | mask | sed -E 's/(TARGET_DB_PASSWORD=).*/\1*****/'
echo "Now run: docker compose up -d --build"
