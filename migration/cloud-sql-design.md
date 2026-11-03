# CloudNotes: Cloud SQL Architecture Design (LU 2.7, Part B)

Design only. Nothing here is created in GCP. Prices are approximate list prices for `asia-south1`; confirm with the GCP pricing calculator.

```
                    cloudnotes-vpc (asia-south1)
 ┌──────────────────────────────────────────────────────────────────────────────┐
 │  web-subnet 10.0.1.0/24     app-subnet 10.0.2.0/24        Private Services     │
 │  ┌──────────────┐           ┌──────────────────────┐      Access 10.10.0.0/16  │
 │  │ nginx (web)  │──tcp:5000─▶│ CloudNotes app       │                          │
 │  └──────────────┘           │ SA: cloudnotes-app@  │──tcp:5432 (private IP,   │
 │         ▲                   │ + Cloud SQL Auth     │   SSL required)──┐       │
 │         │ tcp:80/443        │   Proxy (sidecar)    │                  ▼       │
 │         │                   └──────────┬───────────┘   ┌──────────────────────┐│
 │                                        │ reads secret  │ Cloud SQL PostgreSQL 17││
 │                                        ▼               │ PRIMARY  zone a       ││
 │                              Secret Manager:           │   ⇅ synchronous       ││
 │                              cloudnotes-db-password    │ STANDBY  zone b (HA)  ││
 │                                                        │ NO public IP          ││
 │                                                        └──────────┬───────────┘│
 └───────────────────────────────────────────────────────────────────┼────────────┘
   Internet                                     daily backups + PITR ▼   cross-region
                                                (multi-region storage)   read replica (DR)
                                                                         asia-south2
```

## 1. Database instance

| Decision | Choice | Why |
|---|---|---|
| Engine | **Cloud SQL for PostgreSQL 17**, Enterprise edition | Same major version we migrated to locally, so there are no surprises at cutover |
| Tier (prod) | **`db-custom-1-3840`**: 1 vCPU, 3.75 GB RAM | Right-sized for a small notes app. Dedicated core, covered by the SLA. Scale up later with a short restart |
| Tier (dev/staging) | `db-g1-small` (shared core) | Cheap for testing; shared-core tiers have no SLA |
| Storage | 10 GB SSD, **automatic storage increase** on | The DB is ~8 MB today, so it starts small and never fills up |
| Region | **`asia-south1` (Mumbai)**, zones `a` (primary) / `b` (standby) | Same region as the app VM for low latency, with data kept in India |
| Protection | **Deletion protection** on | One mistaken click can't delete production data |

## 2. Connectivity: private only

- **Private IP only** (`ipv4_enabled = false`). The instance gets an address from the Private Services Access range `10.10.0.0/16`, peered into `cloudnotes-vpc`. It has **no public IP** and no authorized networks.
- **VPC firewall** (from LU 2.4): egress `tcp:5432` is allowed only from `app`-tagged VMs. The web tier can't reach the database.
- **Cloud SQL Auth Proxy** runs as a sidecar next to the app. It authenticates with the app's service account (IAM), encrypts traffic with TLS, and lets the app connect to `127.0.0.1:5432`. **SSL is required** for any direct connection.

## 3. Security: Secret Manager and IAM

| Item | Design |
|---|---|
| DB password | Stored in **Secret Manager** as `cloudnotes-db-password` (auto-replicated, versioned for rotation) |
| How the app gets it | At startup, the app's service account `cloudnotes-app@<project>.iam.gserviceaccount.com` reads the secret and builds `DATABASE_URL` in memory. Nothing in git, the image, or VM metadata |
| IAM roles (least privilege) | App SA: `roles/cloudsql.client` + `roles/secretmanager.secretAccessor` **on that one secret only**. Humans: `roles/cloudsql.viewer`; only the DBA group gets `roles/cloudsql.admin` |
| DB users | App user `cloudnotes` owns only the `cloudnotes` database. Optional **IAM database authentication** for humans (no passwords at all) |
| Exposure | No public IP, no `0.0.0.0/0`, SSL enforced, audit logs (Data Access) on |

Local → cloud: `.env` `DATABASE_URL` → Secret Manager secret, read by the service account.

## 4. Reliability: backups and maintenance

| Setting | Value | Why |
|---|---|---|
| Automated backups | **Daily**, window **02:00–06:00 IST** | Off-peak, no manual work |
| Backup retention | **14 daily backups**, multi-region storage (`asia`) | Two weeks to notice a problem; backups survive a regional outage |
| Point-in-time recovery | **On**, 7 days of transaction logs | Restore to any second, e.g. just before a bad delete |
| On-demand backup | Taken **before every migration or schema change** | A known-good restore point |
| Maintenance window | **Sunday 03:00 IST**, update order "later" | Patches land at the quietest time, after other environments have tested them |
| Restore drill | Restore the latest backup to a temporary instance **monthly** | An untested backup isn't really a backup |

## 5. High availability and disaster recovery

| Item | Design |
|---|---|
| Availability type | **REGIONAL (HA)**: primary in zone `a`, **synchronous standby** in zone `b` |
| Failover | **Automatic**: if zone `a` fails, the standby is promoted in about 60 seconds with the **same IP**, so the app doesn't change anything. Zero committed-data loss (RPO ≈ 0) |
| Disaster recovery (region loss) | **Cross-region read replica** in `asia-south2` (Delhi) that can be promoted. Backups are stored multi-region, so restoring elsewhere is always possible |
| Targets | Zone failure: RTO ≈ 1–2 min, RPO ≈ 0. Region failure: RTO < 1 h (promote replica), RPO seconds to minutes |
| HA is not read scaling | The standby can't serve reads. If reads grow, add read replicas separately |

## 6. Migration and rollback plan (same order as Part A)

1. **Export:** take an on-demand backup of the source, then `pg_dump` (or use **Database Migration Service** for minimal downtime).
2. **Create target:** a Cloud SQL instance configured as above.
3. **Import:** restore through the Auth Proxy.
4. **Verify:** compare table counts, row counts, max ids and the md5 checksum (the same checks as `02-migrate.sh`).
5. **Repoint:** update the `cloudnotes-db-password` / `DATABASE_URL` secret version and restart the app.
6. **Rollback:** if verification or smoke tests fail, point `DATABASE_URL` back at the source (the source is untouched and kept read-only for 7 days), the same as `03-repoint.sh source`. Only then decommission it.

## 7. Cost: single-zone vs regional HA

| | Single-zone (zonal) | Regional HA |
|---|---|---|
| Instance (`db-custom-1-3840`) | ≈ **$50–60 / month** | ≈ **$100–120 / month** (you pay for the standby) |
| Storage 10 GB SSD + backups | ≈ $2–4 / month | ≈ $4–6 / month (storage doubled) |
| Zone failure | **Outage** until recovery or a manual restore | **Automatic failover**, brief blip |
| Good for | Dev / staging / demos | **Production CloudNotes** |

Cloud SQL has **no always-free tier** (the $300 new-account credit covers learning). For dev, use `db-g1-small`, zonal, and stop it when unused.

**Recommendation:** **Regional HA for production** (a zone outage shouldn't take notes offline, and the extra ~$50/month is worth it), with zonal `db-g1-small` for dev/staging.

## 8. Local deployment vs Cloud SQL

| | Local (now) | Cloud SQL (designed) |
|---|---|---|
| Who runs it | Me: patches, upgrades, disk | Google: patching, upgrades, storage growth |
| Backups | Manual `pg_dump` | Automated daily + PITR, multi-region |
| Failure of the machine | Database down | Automatic failover to the standby |
| Secrets | `.env` file on disk | Secret Manager + IAM, rotatable, audited |
| Exposure | Private Docker network | Private IP in the VPC, no public IP, SSL + Auth Proxy |
| Scaling | Limited by one laptop | Change tier, read replicas, auto storage growth |
