# CloudNotes core infrastructure (network, compute, storage) on Google Cloud.
# Zero-cost workflow: terraform init -> validate -> plan. Never apply.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  # Offline, zero-cost planning: a placeholder token means no real credentials
  # or GCP account are needed. Planning brand-new resources makes no API calls.
  access_token = var.access_token
}

locals {
  name_prefix = "cloudnotes-${var.environment}"

  common_labels = merge(var.labels, {
    app         = "cloudnotes"
    environment = var.environment
    managed_by  = "terraform"
  })
}

# ---------------------------------------------------------------- Network ---

resource "google_compute_network" "vpc" {
  name                    = "${local.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "app" {
  name                     = "${local.name_prefix}-app-subnet"
  ip_cidr_range            = var.app_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

# Public HTTP/HTTPS ingress only to instances tagged "web".
resource "google_compute_firewall" "allow_web" {
  name          = "${local.name_prefix}-allow-web"
  network       = google_compute_network.vpc.id
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = var.web_source_ranges
  target_tags   = ["web"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

# SSH only from trusted admin ranges (e.g. IAP), never 0.0.0.0/0.
resource "google_compute_firewall" "allow_ssh_admin" {
  name          = "${local.name_prefix}-allow-ssh-admin"
  network       = google_compute_network.vpc.id
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = var.admin_source_ranges
  target_tags   = ["admin"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# ---------------------------------------------------------------- Compute ---

resource "google_service_account" "app" {
  account_id   = "${local.name_prefix}-app"
  display_name = "CloudNotes app (${var.environment})"
}

resource "google_compute_instance" "app" {
  name         = "${local.name_prefix}-app"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["web", "admin"]
  labels       = local.common_labels

  boot_disk {
    initialize_params {
      image = var.boot_image
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  # Private IP only: no access_config block, so no public IP on the VM.
  network_interface {
    subnetwork = google_compute_subnetwork.app.id
  }

  service_account {
    email  = google_service_account.app.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot = true
  }
}

# ---------------------------------------------------------------- Storage ---

resource "google_storage_bucket" "assets" {
  name                        = var.bucket_name
  location                    = var.bucket_location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = local.common_labels

  versioning {
    enabled = true
  }

  # Move attachments older than N days to the cheaper Nearline class.
  lifecycle_rule {
    condition {
      age = var.nearline_after_days
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }
}

# Least privilege: the app can read/write objects in this bucket only.
resource "google_storage_bucket_iam_member" "app_assets" {
  bucket = google_storage_bucket.assets.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.app.email}"
}
