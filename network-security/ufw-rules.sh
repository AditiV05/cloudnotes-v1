#!/usr/bin/env bash
# The same least-privilege policy as host firewall rules, for a Linux VM
# (VirtualBox/UTM/WSL2 with systemd, or a Compute Engine VM). Run with sudo.
#   sudo TRUSTED_IP=203.0.113.10 bash network-security/ufw-rules.sh
set -euo pipefail
TRUSTED_IP="${TRUSTED_IP:?set TRUSTED_IP to the one IP allowed to SSH in}"

ufw --force reset
ufw default deny incoming                 # default-deny: nothing in unless allowed below
ufw default allow outgoing

ufw allow 80/tcp comment 'web: HTTP from anywhere'
ufw allow 443/tcp comment 'web: HTTPS from anywhere'
ufw allow from "$TRUSTED_IP" to any port 22 proto tcp comment 'admin: SSH from trusted IP only'
ufw deny 5000/tcp comment 'app: never public (nginx proxies to 127.0.0.1:5000)'
ufw deny 5432/tcp comment 'db: never public'

ufw --force enable
ufw status verbose

# Also bind the app to 127.0.0.1:5000 behind nginx (gunicorn --bind 127.0.0.1:5000)
# and keep PostgreSQL on listen_addresses = 'localhost' (the default).
# Note: Docker-published ports bypass ufw, so with Docker use the compose network design instead.
