#!/usr/bin/env bash
# Task 1: inspect the SOURCE database (read-only).
source "$(dirname "$0")/lib.sh"
echo "SOURCE DATABASE ANALYSIS   (service: db)"
line
echo "Database type : $(q db "SELECT split_part(version(), ' on ', 1)")"
echo "Database size : $(q db "SELECT pg_size_pretty(pg_database_size('cloudnotes'))")"
line
echo "Tables:"
qt db "\dt" | sed 's/^/  /'
echo "Row counts:"
qt db "SELECT 'notes' AS table_name, count(*) AS rows FROM notes UNION ALL SELECT 'schema_migrations', count(*) FROM schema_migrations" | sed 's/^/  /'
echo "Existing records (sample):"
qt db "SELECT id, title, left(body, 40) AS body, created_at::timestamp(0) FROM notes ORDER BY id" | sed 's/^/  /'
line
