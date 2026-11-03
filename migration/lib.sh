# Shared helpers for the migration scripts (sourced, not run).
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
line() { echo "--------------------------------------------------------------------------------"; }
# Run SQL in a database container. $1 = service (db | db-target), $2 = SQL
q() { docker compose exec -T "$1" psql -U cloudnotes -d cloudnotes -At -c "$2"; }
qt() { docker compose exec -T "$1" psql -U cloudnotes -d cloudnotes -c "$2"; }
envval() { grep -E "^$1=" .env | tail -1 | cut -d= -f2- | sed 's/[[:space:]]*#.*$//'; }
mask() { sed -E 's#(postgresql://[^:]+:)[^@]+@#\1*****@#'; }
