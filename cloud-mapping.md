# CloudNotes: Local Deployment → Google Compute Engine Mapping

My deployment runs on a free local Linux server. Each piece below has a direct
Compute Engine equivalent. A Linux server is a Linux server: the **same**
`deploy/setup.sh` and `deploy/cloudnotes.service` work unchanged on a Compute
Engine Ubuntu VM.

| # | What I built locally | Compute Engine equivalent | Why they play the same role |
|---|---|---|---|
| 1 | **Linux server**: Ubuntu 24.04 in VirtualBox / UTM / WSL2 / Docker | **Compute Engine VM** (`e2-medium`, Ubuntu 24.04 LTS image) | Both are a dedicated Linux machine whose only job is to run CloudNotes. Compute Engine just rents me the hardware in Google's data center instead of borrowing my laptop's. |
| 2 | **My terminal / shell** (VM console, `ssh -p 2222 user@localhost`, or the WSL terminal) | **`gcloud compute ssh cloudnotes-vm`** (or SSH-in-browser) | Both give me an interactive shell on the server for installing packages and running `systemctl`. `gcloud` also handles the SSH keys for me. |
| 3 | **`localhost:5000` or the VM's IP** (`192.168.x.x:5000` bridged, or a NAT port-forward) | **VM static external IP** (`gcloud compute addresses create`), e.g. `http://34.x.x.x:5000` | Both are the address a browser uses to reach the server. A *static* IP doesn't change when the VM restarts, just like a fixed port-forward rule always points at the same VM. |
| 4 | **OS firewall (`ufw allow 5000/tcp`) / VirtualBox port-forwarding** | **GCP VPC firewall rule** allowing `tcp:5000` ingress to instances with a network tag (e.g. `cloudnotes`) | Both are the gate that decides whether outside traffic can reach port 5000. GCP's rule sits on the VPC network in front of the VM, the way ufw sits in front of my process. With either one closed, the app runs fine and the page still won't load. |
| 5 | **systemd service** (`deploy/cloudnotes.service`, `Restart=always`, `systemctl enable`) | **systemd on the VM** (identical unit file) | Compute Engine Ubuntu images use systemd too, so the same file gives the same start-on-boot and restart-on-crash behavior with no changes. |
| 6 | **PostgreSQL 16 on the same Linux server** (`localhost:5432`) | **Cloud SQL for PostgreSQL** (managed, covered in LU 2.7) | Both are a real relational database that stores notes independently of the app process, which is why notes survive restarts. Cloud SQL adds managed backups, patching, high availability and replicas, so I'd only change `DATABASE_URL`. |
| 7 | **`.env` file / environment variables** (`DATABASE_URL`, `SECRET_KEY`, loaded by systemd's `EnvironmentFile=`) | **Instance metadata** for non-secret config + **Secret Manager** for passwords and keys | Both keep configuration and secrets out of the code and out of git. On GCP, the VM's service account reads secrets from Secret Manager at startup instead of from a file on disk. |

## Extra mappings (beyond the minimum)

| Local | Compute Engine | Why |
|---|---|---|
| `deploy/setup.sh`, run by hand once | VM **startup script** (`--metadata-from-file startup-script=deploy/setup.sh`) | Both bootstrap a fresh server automatically. GCP runs it on first boot for me. |
| VM disk (`/var/lib/postgresql`, `uploads/`) | **Persistent Disk** attached to the VM (later, Cloud Storage for uploads) | Both are block storage that survives reboots of the machine. |
| VirtualBox NAT / host-only network | **VPC network + subnet** | Both are the private network the server lives on. Firewall rules attach to it. |
| `GET /health` checked with curl | **Health checks** for load balancers / managed instance groups | Same endpoint, polled automatically to decide if the instance is healthy. |
| VM snapshot in VirtualBox | **Disk snapshot / machine image** | Both are a point-in-time copy of the server for backup or cloning. |

## The same deployment on Compute Engine (commands)

```bash
gcloud compute instances create cloudnotes-vm \
  --zone=asia-south1-a --machine-type=e2-medium \
  --image-family=ubuntu-2404-lts-amd64 --image-project=ubuntu-os-cloud \
  --tags=cloudnotes

gcloud compute firewall-rules create allow-cloudnotes-5000 \
  --network=default --direction=INGRESS --action=ALLOW \
  --rules=tcp:5000 --target-tags=cloudnotes --source-ranges=0.0.0.0/0

gcloud compute ssh cloudnotes-vm --zone=asia-south1-a
# then, on the VM, exactly the same as locally:
git clone https://github.com/AditiV05/cloudnotes-v1.git && cd cloudnotes-v1
sudo bash deploy/setup.sh
```

## What changes vs. what stays the same

- **Stays the same:** the app code, `requirements.txt`, gunicorn, the 0.0.0.0 bind, the systemd unit, the migrations, the setup steps.
- **Changes:** where the machine lives (Google's data center), how I reach the shell (`gcloud compute ssh`), where the firewall is configured (VPC rule instead of, or in addition to, ufw), where secrets live (Secret Manager), and eventually where the database lives (Cloud SQL).

**One-sentence takeaway:** a demo that only works while I'm watching is not a deployment. It has to survive logout, crashes and reboots. The Compute Engine equivalent of the `ufw allow 5000/tcp` rule I opened is a **VPC firewall rule allowing ingress on tcp:5000**.
