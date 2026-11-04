# The module's outputs. Callers read these, not the resources inside.

output "network_id" {
  description = "ID of the VPC."
  value       = google_compute_network.vpc.id
}

output "network_name" {
  description = "Name of the VPC."
  value       = google_compute_network.vpc.name
}

output "subnet_id" {
  description = "ID of the subnet."
  value       = google_compute_subnetwork.subnet.id
}

output "subnet_cidr" {
  description = "CIDR range of the subnet."
  value       = google_compute_subnetwork.subnet.ip_cidr_range
}
