#!/usr/bin/env bash
# One-shot setup for CloudNotes on Ubuntu 22.04/24.04
# (VirtualBox / UTM VM, WSL2 Ubuntu with systemd, or a Compute Engine VM).
#
# Run from inside the cloned repo:   sudo bash deploy/setup.sh
set -euo pipefail

APP_USER=cloudnotes
APP_DIR=/home/$APP_USER/cloudnotes
DB_NAME=cloudnotes
DB_USER=cloudnotes
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $EUID -ne 0 ]]; then echo "Run with sudo: sudo bash deploy/setup.sh"; exit 1; fi

echo "==> 1/7 Installing system packages (Python, PostgreSQL, ufw)"
apt-get update -y
apt-get install -y python3 python3-venv python3-pip postgresql postgresql-contrib ufw rsync

echo "==> 2/7 Creating service user '$APP_USER'"
id -u "$APP_USER" >/dev/null 2>&1 || useradd --create-home --shell /bin/bash "$APP_USER"

echo "==> 3/7 Copying code to $APP_DIR"
mkdir -p "$APP_DIR"
rsync -a --delete --exclude venv --exclude .env --exclude .git "$REPO_DIR"/ "$APP_DIR"/
mkdir -p "$APP_DIR/uploads"

echo "==> 4/7 Creating Python virtualenv and installing dependencies"
python3 -m venv "$APP_DIR/venv"
"$APP_DIR/venv/bin/pip" install --upgrade pip
"$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt"

echo "==> 5/7 Setting up PostgreSQL database and user"
systemctl enable --now postgresql
if [[ ! -f "$APP_DIR/.env" ]]; then
  DB_PASS="$(python3 -c 'import secrets; print(secrets.token_urlsafe(18))')"
  SECRET="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
  sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$DB_USER') THEN
    CREATE ROLE $DB_USER LOGIN PASSWORD '$DB_PASS';
  ELSE
    ALTER ROLE $DB_USER WITH PASSWORD '$DB_PASS';
  END IF;
END \$\$;
SQL
  sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 \
    || sudo -u postgres createdb -O "$DB_USER" "$DB_NAME"
  cat > "$APP_DIR/.env" <<ENV
DATABASE_URL=postgresql://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME
SECRET_KEY=$SECRET
UPLOAD_FOLDER=$APP_DIR/uploads
ENV
  chmod 600 "$APP_DIR/.env"
  echo "    wrote $APP_DIR/.env (real secrets, never committed)"
else
  echo "    $APP_DIR/.env already exists, keeping it"
fi
chown -R "$APP_USER:$APP_USER" "/home/$APP_USER"

echo "==> 6/7 Running migrations"
sudo -u "$APP_USER" bash -c "cd $APP_DIR && venv/bin/python migrate.py"

echo "==> 7/7 Installing systemd service and opening port 5000"
cp "$APP_DIR/deploy/cloudnotes.service" /etc/systemd/system/cloudnotes.service
systemctl daemon-reload
systemctl enable --now cloudnotes
ufw allow OpenSSH >/dev/null
ufw allow 5000/tcp
ufw --force enable

sleep 2
systemctl --no-pager status cloudnotes | head -n 12
echo
curl -s http://localhost:5000/health && echo
echo "Done. Open http://<server-ip>:5000/notes in your browser."
