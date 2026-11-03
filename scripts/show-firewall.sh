#!/usr/bin/env bash
# Prints the CloudNotes firewall configuration on one screen (for Screenshot 1).
cd "$(dirname "$0")/.."
line() { echo "--------------------------------------------------------------------------------"; }
echo "CLOUDNOTES FIREWALL CONFIGURATION  (Docker networks + nginx, default-deny)"
line
echo "1) PUBLISHED PORTS - the only doors open to the host/public (everything else denied):"
docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'
echo
echo "   web (nginx) 0.0.0.0:80 -> ALLOWED from anywhere (HTTP ingress)"
echo "   app 5000/tcp, db 5432/tcp -> NOT published = BLOCKED from host/public"
line
echo "2) NETWORK SEGMENTATION - which tier can talk to which:"
for svc in web app db; do
  cid=$(docker compose ps -q "$svc")
  nets=$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$cid" | sed 's/[a-z0-9-]*_//g')
  printf '   %-4s -> networks: %s\n' "$svc" "$nets"
done
for net in web data; do
  name=$(docker network ls --format '{{.Name}}' | grep "_${net}$" | head -1)
  printf '   network %-5s internal(no internet)=%s\n' "$net" "$(docker network inspect -f '{{.Internal}}' "$name")"
done
echo "   => web<->app allowed (share 'web'), app<->db allowed (share 'data'), web<->db DENIED"
line
echo "3) NGINX ACCESS CONTROLS (web tier):"
grep -nE 'listen|server_tokens|request_method|location|allow|deny|proxy_pass' nginx/nginx.conf | sed 's/^/   /'
line
echo "4) ADMIN / SSH ACCESS:"
if command -v ufw >/dev/null 2>&1; then
  sudo ufw status numbered 2>/dev/null | sed 's/^/   /'
else
  echo "   Containers run NO SSH server; port 22 is not published by any container."
  echo "   Admin access = 'docker compose exec' from this machine only (needs local login)."
  if [[ "$(uname)" == "Darwin" ]]; then
    if nc -z -w 2 localhost 22 >/dev/null 2>&1; then
      echo "   SSH (port 22) on this Mac: OPEN  -> turn off Remote Login (System Settings > General > Sharing)"
    else
      echo "   SSH (port 22) on this Mac: CLOSED (Remote Login is off) -> no remote admin access"
    fi
  fi
fi
line
