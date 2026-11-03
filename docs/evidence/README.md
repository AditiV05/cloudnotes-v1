# Deployment evidence

`local-test-log.txt` is a recorded run of gunicorn + PostgreSQL showing `/health`,
creating a note, stopping and restarting the app, and the note still being there.

**Add your own screenshots from your VM here** (replace the names if you like):

| File | What it should show |
|---|---|
| `01-vm-running.png` | Your VirtualBox / UTM / WSL window with Ubuntu running |
| `02-systemctl-status.png` | `sudo systemctl status cloudnotes` → `active (running)` |
| `03-crash-restart.png` | `kill -9 <PID>`, then `systemctl status` with a **new** PID |
| `04-after-reboot.png` | `systemctl status cloudnotes` right after `sudo reboot` |
| `05-ufw-status.png` | `sudo ufw status` showing `5000/tcp ALLOW` + `ss -tlnp \| grep 5000` |
| `06-browser.png` | CloudNotes `/notes` page open in your host browser |
| `07-persistence.png` | Note still listed after `systemctl restart cloudnotes` / reboot |
| `08-psql.png` | `SELECT * FROM notes;` in PostgreSQL |
