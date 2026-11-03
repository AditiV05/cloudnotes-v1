#!/usr/bin/env bash
# Connectivity tests for the CloudNotes network design (run from the repo folder, stack running).
# Prints ALLOWED / BLOCKED for each path and whether that is what we expect.
cd "$(dirname "$0")/.."
pass=0; fail=0
check() { # $1=description $2=expected(ALLOWED|BLOCKED) $3...=command (exit 0 = connected)
  local desc="$1" expected="$2"; shift 2
  if "$@" >/dev/null 2>&1; then got=ALLOWED; else got=BLOCKED; fi
  if [[ "$got" == "$expected" ]]; then mark="PASS"; pass=$((pass+1)); else mark="FAIL"; fail=$((fail+1)); fi
  printf '  [%s] %-46s -> %-7s (expected %s)\n' "$mark" "$desc" "$got" "$expected"
}
tcp() { nc -z -w 3 "$1" "$2"; }

echo "CloudNotes network verification"
echo "--------------------------------------------------------------------------------"
echo "From the host / public side:"
check "public -> web   (http://localhost:80)"     ALLOWED curl -sf -o /dev/null http://localhost/notes
check "public -> app   (localhost:5000 direct)"   BLOCKED tcp localhost 5000
check "public -> db    (localhost:5432)"          BLOCKED tcp localhost 5432
echo "Between tiers (inside Docker):"
check "web tier -> app tier (app:5000)"           ALLOWED docker compose exec -T web wget -q -O /dev/null http://app:5000/notes
check "app tier -> db tier  (db:5432)"            ALLOWED docker compose exec -T app python -c "import socket; socket.create_connection(('db',5432),3)"
check "web tier -> db tier  (db:5432)"            BLOCKED docker compose exec -T web nc -z -w 3 db 5432
check "db tier  -> internet (egress)"             BLOCKED docker compose exec -T db bash -c "exec 3<>/dev/tcp/1.1.1.1/443"
echo "--------------------------------------------------------------------------------"
echo "  $pass passed, $fail failed"
[[ $fail -eq 0 ]]
