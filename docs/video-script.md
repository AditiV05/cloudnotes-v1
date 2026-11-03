# Video walkthrough script (4–6 minutes)

Have your VM running, a terminal SSH'd in, and a host browser ready. Keep your face/voice on as required.

| Time | Requirement | What to do and say |
|---|---|---|
| 0:00–0:30 | **1. Linux environment** | Show the VirtualBox/UTM/WSL window. Run `lsb_release -a` and `hostname -I`. "This is my Ubuntu server, a free local VM." |
| 0:30–1:00 | **2. CloudNotes running** | `curl localhost:5000/health`. "It's running under gunicorn, bound to 0.0.0.0:5000." Show `ss -tlnp \| grep 5000`. |
| 1:00–2:15 | **3. Service proof** | `sudo systemctl status cloudnotes` (point at *enabled* + *active (running)* + PID). `sudo kill -9 $(systemctl show -p MainPID --value cloudnotes)`, wait 4s, `systemctl status` again showing a new PID. "Restart=always healed it." Then `sudo reboot`, reconnect, `systemctl status`. "WantedBy=multi-user.target plus enable started it on boot." |
| 2:15–3:00 | **4. Browser access** | `sudo ufw status` (5000/tcp ALLOW). Open `http://<vm-ip or localhost>:5000/notes` in the host browser. Walk the path: browser → VM network → ufw → Linux → gunicorn/Flask. |
| 3:00–4:00 | **5. Persistence** | Add a note in the browser. `sudo systemctl restart cloudnotes`. Refresh, the note is still there. Show `sudo -u postgres psql cloudnotes -c "SELECT * FROM notes;"`. "Data lives in PostgreSQL, not the process." |
| 4:00–5:30 | **6. Compute Engine mapping** | Open `cloud-mapping.md` and go row by row: VM → e2-medium VM, shell → gcloud compute ssh, IP → static external IP, ufw → VPC firewall rule tcp:5000, systemd → same systemd, PostgreSQL → Cloud SQL, .env → Secret Manager. |
| 5:30–6:00 | Wrap-up | Show the PR on GitHub. "A deployment survives logout, crash and reboot. The cloud version of my ufw rule is a VPC firewall rule." |
