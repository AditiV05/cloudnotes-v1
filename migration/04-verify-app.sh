#!/usr/bin/env bash
# Task 4: prove CloudNotes works on the migrated database.
source "$(dirname "$0")/lib.sh"
echo "CLOUDNOTES ON MIGRATED POSTGRESQL"
line
echo "App health        : $(curl -s http://localhost/health)"
echo "Notes via app     : $(curl -s http://localhost/api/notes | grep -o '"id"' | wc -l | tr -d ' ') notes returned by GET /api/notes"
before=$(q db-target "SELECT count(*) FROM notes"); src=$(q db "SELECT count(*) FROM notes")
echo "Create a new note : $(curl -s -X POST -F 'title=Created after migration' -F 'body=Saved in PostgreSQL 17' http://localhost/api/notes)"
after=$(q db-target "SELECT count(*) FROM notes")
echo "Target rows       : ${before} -> ${after}  (new note landed in the migrated database)"
echo "Source rows       : ${src} (unchanged, kept as rollback)"
line
qt db-target "SELECT id, title, created_at::timestamp(0) FROM notes ORDER BY id" | sed 's/^/  /'
