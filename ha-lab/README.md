# CloudNotes HA failover lab (LU 5.8)

Two CloudNotes replicas (`app1`, `app2`, the real app from this repo) behind **HAProxy** at the one client URL
`http://127.0.0.1:8080`, sharing one persistent **PostgreSQL** store. `drill.py` kills `app1` and measures recovery.

```
client ──► 127.0.0.1:8080  HAProxy (round robin, GET /health every 1s, fall 2, rise 2)
                              ├──► app1:5000  (X-Served-By: app1)  ──┐
                              └──► app2:5000  (X-Served-By: app2)  ──┴──► PostgreSQL (volume lab-notes)
```

| Run (inside `ha-lab/`) | What it does |
|---|---|
| `docker compose pull` / `docker compose up -d --wait` | pull images, build the app, start db, app1, app2, proxy (waits for health checks) |
| `python3 drill.py baseline` | confirms both identities through the proxy, saves 3 acknowledged notes to `baseline.json` |
| `python3 drill.py targets` | prints the RTO/RPO targets, scope and method (`TARGETS.md`). Run **before** the failure |
| `python3 drill.py failover` | SIGKILLs app1, probes the **same URL** every 0.5 s for 15 s, compares notes exactly, writes + reads a new note, saves `result.json` and `failover.log` |
| `python3 drill.py report` | prints `result.json` and the target / result / verdict table |
| `docker compose start app1` then `python3 drill.py status` | manual capacity restore, then confirms both identities again |
| `docker compose down` | stop (keeps notes). `down -v` deletes the lab notes |

Scope: only the app1 process fails. The proxy, the database volume and the laptop remain single points of failure. This is an HA test, not disaster recovery.
