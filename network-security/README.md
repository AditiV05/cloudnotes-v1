# CloudNotes Network Security (LU 2.4)

CloudNotes is split into **tiers**, and each tier only accepts traffic from the tier above it,
on the one port it needs. **Everything else is denied by default.**

Environment: Docker Desktop (Linux containers), the same stack as LU 2.2, plus an nginx web tier.
Enforced with **Docker networks** (segmentation) + **nginx** (single public entry point + access controls).
A `ufw` version of the same policy for a Linux VM / Compute Engine VM is in [`ufw-rules.sh`](ufw-rules.sh).

---

## Task 1: Security design

```
                         INGRESS tcp:80 (HTTP)           tcp:5000                  tcp:5432
  ┌──────────────┐  ✅   ┌────────────────────┐   ✅   ┌──────────────────┐   ✅   ┌──────────────────┐
  │ Client/User  │ ────▶ │  WEB TIER          │ ─────▶ │  APP TIER        │ ─────▶ │  DATABASE TIER   │
  │ 0.0.0.0/0    │       │  nginx :80         │        │  gunicorn/Flask  │        │  PostgreSQL      │
  │ (internet)   │       │  network: web      │        │  :5000           │        │  :5432           │
  └──────────────┘       │  PUBLIC            │        │  networks: web + │        │  network: data   │
         │               └────────────────────┘        │  data  PRIVATE   │        │  (internal)      │
         │                        │                    └──────────────────┘        │  PRIVATE         │
         │   ❌ tcp:5000 (public → app)  DENIED                                     └──────────────────┘
         ├──────────────────────────────────────────────────────▶ app                       ▲
         │   ❌ tcp:5432 (public → db)   DENIED                                              │
         └────────────────────────────────────────────────────────────────────────────────▶ ❌
                                  ❌ web → db tcp:5432 DENIED (no shared network)
                                  ❌ db → internet EGRESS DENIED (internal network)

  ┌──────────────┐  🔒 tcp:22 ONLY from a trusted source (admin IP / IAP). Never 0.0.0.0/0.
  │ Admin (SSH)  │ ─── Locally: no SSH server in any container; admin = `docker compose exec` on the host.
  └──────────────┘
```

### Security boundaries and rules

| Tier | Ingress allowed | Source | Destination | Everything else |
|---|---|---|---|---|
| Web (nginx) | tcp:80 (HTTP), tcp:443 (HTTPS, once TLS is added) | 0.0.0.0/0 (public) | web tier | denied |
| App (Flask/gunicorn) | tcp:5000 | web tier only | app tier | denied (public cannot reach 5000) |
| Database (PostgreSQL) | tcp:5432 | app tier only | db tier | denied (public **and** web cannot reach 5432) |
| Admin (SSH) | tcp:22 | one trusted IP / IAP range | admin host | denied from 0.0.0.0/0 |

| Egress | Allowed? |
|---|---|
| web → app :5000 | ✅ |
| app → db :5432 | ✅ |
| app → internet (e.g. package updates) | ✅ |
| db → internet | ❌ (internal network, no route out) |

**Default-deny:** a container port is unreachable from outside unless it is published under `ports:`.
Only nginx publishes a port (80). On a VM the same idea is `ufw default deny incoming`.

---

## Task 2: Implementation (commands and configuration)

| File | What it enforces |
|---|---|
| [`../docker-compose.yml`](../docker-compose.yml) | Only `web` publishes a port (`80:80`). `app` uses `expose: 5000` (container-only). `db` publishes nothing. Two networks: `web` (nginx + app) and `data` (app + db, `internal: true`). |
| [`../nginx/nginx.conf`](../nginx/nginx.conf) | Single public entry point, reverse proxy to `app:5000`, only GET/HEAD/POST/DELETE (others → 405), `/health` admin endpoint allowed only from local/private ranges (`deny all` for the public), no version banner, security headers. |
| [`ufw-rules.sh`](ufw-rules.sh) | Same policy as host firewall rules for a Linux VM / Compute Engine VM (`ufw default deny incoming`, allow 80/443, SSH only from a trusted IP). |

Commands used:
```bash
docker compose down                 # stop the LU 2.2 stack (port 5000 was public)
docker compose up -d --build        # start the tiered stack: web + app + db
scripts/show-firewall.sh            # print the active firewall configuration (Screenshot 1)
```

Key configuration (from `docker-compose.yml`):
```yaml
web:  ports: ["80:80"]       networks: [web]        # the ONE public door
app:  expose: ["5000"]       networks: [web, data]  # private: only nginx can reach it
db:   (no ports)             networks: [data]       # private: only the app can reach it
networks:
  web:
  data: { internal: true }                          # no ingress from / egress to the outside
```

---

## Task 3: Verification (allowed vs blocked)

Run `scripts/verify-network.sh`. Recorded result:

```
From the host / public side:
  [PASS] public -> web   (http://localhost:80)          -> ALLOWED (expected ALLOWED)
  [PASS] public -> app   (localhost:5000 direct)        -> BLOCKED (expected BLOCKED)
  [PASS] public -> db    (localhost:5432)               -> BLOCKED (expected BLOCKED)
Between tiers (inside Docker):
  [PASS] web tier -> app tier (app:5000)                -> ALLOWED (expected ALLOWED)
  [PASS] app tier -> db tier  (db:5432)                 -> ALLOWED (expected ALLOWED)
  [PASS] web tier -> db tier  (db:5432)                 -> BLOCKED (expected BLOCKED)
  [PASS] db tier  -> internet (egress)                  -> BLOCKED (expected BLOCKED)
  7 passed, 0 failed
```

Manual checks:
```bash
curl -I http://localhost/notes          # HTTP/1.1 200 OK  (allowed: through nginx)
nc -zv localhost 5432                   # Connection refused (blocked: db not published)
nc -zv localhost 5000                   # Connection refused (blocked: app is private)
docker compose exec web nc -zv db 5432  # bad address 'db' (blocked: web tier can't even see the db)
curl -X PUT http://localhost/notes      # 405 (blocked: method not allowed)
```

---

## Task 4: GCP firewall mapping

Target design: one custom VPC `cloudnotes-vpc` with three subnets: **web 10.0.1.0/24**, **app 10.0.2.0/24**, **db 10.0.3.0/24**.
VMs carry network tags `web`, `app`, `db`. GCP's implied rules already **deny all ingress** (priority 65535).

| # | Local rule | Direction | Source | Destination | Port | GCP equivalent rule | What it protects |
|---|---|---|---|---|---|---|---|
| 1 | Allow HTTP (nginx `ports: 80:80`) | Ingress | 0.0.0.0/0 | web tier | tcp:80 | `allow-web-http`: ALLOW tcp:80, source-ranges 0.0.0.0/0, target-tags `web` | Opens only the public front door |
| 2 | Allow HTTPS (when TLS is added) | Ingress | 0.0.0.0/0 | web tier | tcp:443 | `allow-web-https`: ALLOW tcp:443, source-ranges 0.0.0.0/0, target-tags `web` | Encrypted public access |
| 3 | Allow web → app (shared `web` network) | Ingress | web tier | app tier | tcp:5000 | `allow-web-to-app`: ALLOW tcp:5000, source-tags `web`, target-tags `app` | App only accepts traffic from nginx |
| 4 | Allow app → db (shared `data` network) | Ingress | app tier | db tier | tcp:5432 | `allow-app-to-db`: ALLOW tcp:5432, source-tags `app` (or app service account), target-tags `db` | Only the app can read/write data |
| 5 | Block public → app (5000 not published) | Ingress | 0.0.0.0/0 | app tier | tcp:5000 | No allow rule → implied deny; app VMs have **no external IP** | App can't be attacked directly |
| 6 | Block public → db (5432 not published) | Ingress | 0.0.0.0/0 | db tier | tcp:5432 | `deny-public-db`: DENY tcp:5432, source-ranges 0.0.0.0/0, target-tags `db`, priority 900; db has no external IP | Database never exposed to the internet |
| 7 | Block web → db (no shared network) | Ingress | web tier | db tier | tcp:5432 | Only `app` is in rule 4's source → web is denied by default | A hacked web server can't reach data |
| 8 | Block db → internet (`internal: true`) | Egress | db tier | 0.0.0.0/0 | all | `deny-db-egress`: DENY all egress, target-tags `db`; no Cloud NAT for the db subnet | Stops data being sent out (exfiltration) |
| 9 | Restricted SSH / admin (no SSH server; `docker exec` from host only) | Ingress | Trusted IP only | admin access | tcp:22 | `allow-ssh-iap`: ALLOW tcp:22, source-ranges `35.235.240.0/20` (IAP) or `<your-ip>/32`, target-tags `admin` | Admin access only from a trusted source |
| 10 | Restricted `/health` (nginx `allow` private / `deny all`) | Ingress | private ranges | web tier path | tcp:80 | Cloud Armor policy / internal-only health check source `35.191.0.0/16`, `130.211.0.0/22` | Monitoring endpoint not open to the public |
| 11 | Default deny (unpublished ports) | Ingress | any | any | any | Implied rule: DENY all ingress, priority 65535 | Anything not explicitly allowed is blocked |

The same rules as `gcloud` commands and Terraform are in [`gcp-firewall.md`](gcp-firewall.md).

---

## Task 5: Security posture summary

- **Allowed traffic:** the public can reach only the web tier (nginx) on **tcp:80** (and 443 once TLS is added). nginx forwards to the app on **tcp:5000**, and only the app connects to PostgreSQL on **tcp:5432**.
- **Denied traffic:** direct public access to the app (5000) and the database (5432), web → database, database → internet, unused HTTP methods (PUT/PATCH → 405), and every port that is not explicitly published (**default-deny**).
- **How the database is protected:** it publishes no port, lives on an `internal` network that only the app tier joins, and has no route to the internet. Even if the web server were compromised, it cannot see the database (`bad address 'db'`). Its password comes from `.env`, never from git.
- **How admin access is controlled:** no container runs an SSH server, and port 22 is never published. Admin work is done with `docker compose exec` from the host, which requires logging into the machine. The `/health` endpoint only answers private/local addresses. On a VM: `ufw allow from <trusted-ip> to any port 22`. In GCP: SSH only through IAP (`35.235.240.0/20`) to `admin`-tagged VMs.
- **Cloud translation:** each tier becomes its own subnet (web/app/db) in a custom VPC. Docker network membership becomes network tags (or service accounts), and "published port" becomes a VPC ingress allow rule. Docker's default-deny becomes GCP's implied deny-all-ingress. The db subnet gets no external IPs and no Cloud NAT.
- **Least privilege:** each tier gets exactly one inbound port from exactly one source, and nothing more. Security is verified with connectivity tests, not assumed.
