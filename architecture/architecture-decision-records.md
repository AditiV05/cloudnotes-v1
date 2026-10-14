# CloudNotes: Architecture Decision Records

Project: CloudNotes v1.0 to GCP migration proposal
Region: asia-south1 (Mumbai)
Status of all decisions: Accepted (proposal stage, not deployed)

---

## ADR-001: Use Cloud SQL for PostgreSQL (HA) instead of SQLite

**Decision:**
Move the `notes` table from the SQLite file `database/cloudnotes.db` to Cloud SQL for PostgreSQL with high availability (primary in zone a, synchronous standby in zone b), reachable only on a private IP.

**Context:**
SQLite is a single file on one machine's disk. In the cloud, the app runs on several VMs at once, and each VM would get its own separate copy of the database, so users would see different notes depending on which VM served them. SQLite also has no built-in replication or automatic failover.

**Alternatives:**
1. Keep SQLite on one Compute Engine VM with a persistent disk.
2. Run PostgreSQL ourselves on a Compute Engine VM.
3. Firestore (NoSQL, serverless).

**Trade-off:**
Higher monthly cost than SQLite (which is free) and a small network hop for every query. In return we get one shared database for all VMs, automated daily backups, point-in-time recovery, patching handled by Google, and automatic zone failover. Firestore was rejected because the app already uses SQL queries, and switching would mean rewriting the data layer.

---

## ADR-002: Run the Flask app on a regional Managed Instance Group of Compute Engine VMs

**Decision:**
Package the existing Flask code with Gunicorn into an instance template and run it in a regional Managed Instance Group (MIG) across asia-south1-a and asia-south1-b. Autoscale from 2 to 10 VMs at 60% target CPU.

**Context:**
Today the app runs with the Flask development server (`debug=True`) on one laptop. That is a single point of failure and cannot handle more traffic than one machine. The code should run unchanged, and the team is already learning Linux and VMs in this module.

**Alternatives:**
1. A single Compute Engine VM with a public IP.
2. Cloud Run (serverless containers).
3. Google Kubernetes Engine (GKE).

**Trade-off:**
A MIG is more work to manage than Cloud Run (OS patching, instance templates), and we pay for at least 2 VMs even with zero traffic. In return we get full control of the Linux environment, private subnet placement with firewall rules, autohealing, and autoscaling. A single VM was rejected because it has no redundancy. GKE was rejected because it adds a lot of complexity for one small app.

---

## ADR-003: Store uploads and static assets in Cloud Storage

**Decision:**
Store user attachments in a private Cloud Storage bucket (versioning on, files served via short-lived signed URLs). Serve `static/` from a second bucket behind the load balancer with Cloud CDN.

**Context:**
The app saves uploads to the local `uploads/` folder. With many VMs, a file uploaded to VM A does not exist on VM B, and when the MIG replaces a VM its local disk is deleted. Also, `secure_filename()` keeps the original name, so two users uploading `notes.pdf` overwrite each other.

**Alternatives:**
1. Keep files on each VM's local disk.
2. Filestore (managed NFS shared by all VMs).
3. Store files as BLOBs in Cloud SQL.

**Trade-off:**
The upload code must change from writing to a local path to calling the Cloud Storage API, and object names need a unique prefix. In return files are shared by every VM, survive VM replacement, have 99.999999999% durability, and cost much less than Filestore. Storing files in the database was rejected because it bloats backups and slows queries.

---

## ADR-004: Only the load balancer is public; app and database stay in private subnets

**Decision:**
Use a custom VPC. The external HTTPS load balancer is the only resource with a public IP. App VMs have no external IPs and sit in private subnet 10.10.1.0/24. Cloud SQL uses a private IP in 10.20.0.0/24. Firewall rules allow only: LB and health-check ranges to tcp:8080, the app subnet to tcp:5432, and the IAP range to tcp:22. Cloud NAT gives VMs outbound-only internet for updates.

**Context:**
Locally the app listens on 127.0.0.1:5000 over plain HTTP. On the internet, any VM with a public IP gets scanned and attacked within minutes, and the database must never be reachable from outside.

**Alternatives:**
1. Give each VM a public IP and use firewall rules only.
2. Use the default VPC with its permissive default rules.

**Trade-off:**
More setup (Cloud NAT, IAP for SSH, Private Service Access for Cloud SQL), and debugging needs IAP tunnels instead of direct SSH. In return the attack surface is one HTTPS endpoint protected by Cloud Armor, TLS is handled by a Google-managed certificate, and a compromised VM still cannot be reached directly from the internet.

---

## ADR-005: Least-privilege service account and Secret Manager

**Decision:**
Attach a dedicated service account `cloudnotes-app-sa` to the VMs, with only: Cloud SQL client, object admin on the uploads bucket, secret accessor on 2 secrets, log writer, and metric writer. Store the DB password and Flask secret key in Secret Manager.

**Context:**
The default Compute Engine service account has the broad Editor role. If the app is compromised, an attacker would control the whole project. Putting passwords in code, `.env` files or VM images leaks them to anyone with repo or image access.

**Alternatives:**
1. Use the default Compute Engine service account.
2. Keep secrets in a `.env` file baked into the VM image (the app already lists `python-dotenv`).

**Trade-off:**
More IAM setup, and every new permission must be granted on purpose. In return a compromised VM can only touch CloudNotes data, secrets can be rotated without rebuilding images, and every secret access is logged for audit.
