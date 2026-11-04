# A reusable network: one VPC, one subnet, and one ingress firewall rule.
# Everything that varies between uses comes from an input variable.

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "subnet" {
  name                     = "${var.network_name}-subnet"
  ip_cidr_range            = var.cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

resource "google_compute_firewall" "allow" {
  name          = "${var.network_name}-allow"
  network       = google_compute_network.vpc.id
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = var.source_ranges
  target_tags   = var.target_tags

  allow {
    protocol = "tcp"
    ports    = var.allowed_ports
  }
}
