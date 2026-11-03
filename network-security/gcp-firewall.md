# CloudNotes: GCP VPC firewall rules (mapping, not deployed)

```bash
# Custom VPC with one subnet per tier
gcloud compute networks create cloudnotes-vpc --subnet-mode=custom
gcloud compute networks subnets create web-subnet --network=cloudnotes-vpc --region=asia-south1 --range=10.0.1.0/24
gcloud compute networks subnets create app-subnet --network=cloudnotes-vpc --region=asia-south1 --range=10.0.2.0/24
gcloud compute networks subnets create db-subnet  --network=cloudnotes-vpc --region=asia-south1 --range=10.0.3.0/24

# 1-2: public -> web (HTTP/HTTPS)
gcloud compute firewall-rules create allow-web-http-https --network=cloudnotes-vpc \
  --direction=INGRESS --action=ALLOW --rules=tcp:80,tcp:443 \
  --source-ranges=0.0.0.0/0 --target-tags=web

# 3: web -> app only
gcloud compute firewall-rules create allow-web-to-app --network=cloudnotes-vpc \
  --direction=INGRESS --action=ALLOW --rules=tcp:5000 \
  --source-tags=web --target-tags=app

# 4: app -> db only
gcloud compute firewall-rules create allow-app-to-db --network=cloudnotes-vpc \
  --direction=INGRESS --action=ALLOW --rules=tcp:5432 \
  --source-tags=app --target-tags=db

# 6: explicit deny public -> db (defence in depth; also give db VMs no external IP)
gcloud compute firewall-rules create deny-public-db --network=cloudnotes-vpc \
  --direction=INGRESS --action=DENY --rules=tcp:5432 --priority=900 \
  --source-ranges=0.0.0.0/0 --target-tags=db

# 8: db has no internet egress
gcloud compute firewall-rules create deny-db-egress --network=cloudnotes-vpc \
  --direction=EGRESS --action=DENY --rules=all \
  --destination-ranges=0.0.0.0/0 --target-tags=db

# 9: SSH only via Identity-Aware Proxy (or replace with <your-ip>/32)
gcloud compute firewall-rules create allow-ssh-iap --network=cloudnotes-vpc \
  --direction=INGRESS --action=ALLOW --rules=tcp:22 \
  --source-ranges=35.235.240.0/20 --target-tags=admin

# 11: everything else -> implied deny-all ingress (priority 65535), nothing to create
```

## Terraform equivalent (excerpt)

```hcl
resource "google_compute_firewall" "allow_app_to_db" {
  name        = "allow-app-to-db"
  network     = google_compute_network.cloudnotes.id
  direction   = "INGRESS"
  source_tags = ["app"]
  target_tags = ["db"]
  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }
}

resource "google_compute_firewall" "allow_ssh_iap" {
  name          = "allow-ssh-iap"
  network       = google_compute_network.cloudnotes.id
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["admin"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
```

In production: Cloud NAT gives the **app** subnet outbound internet without public IPs (none for db),
and Cloud DNS gives the web tier a real name. These are described here, not built.
