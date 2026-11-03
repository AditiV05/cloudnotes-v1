output "instance_name" {
  description = "Name of the CloudNotes app VM."
  value       = google_compute_instance.app.name
}

output "instance_ip" {
  description = "Private IP address of the CloudNotes app VM."
  value       = google_compute_instance.app.network_interface[0].network_ip
}

output "bucket_name" {
  description = "Name of the Cloud Storage bucket for CloudNotes assets."
  value       = google_storage_bucket.assets.name
}

output "bucket_url" {
  description = "gs:// URL of the assets bucket."
  value       = google_storage_bucket.assets.url
}

output "network_name" {
  description = "Name of the CloudNotes VPC network."
  value       = google_compute_network.vpc.name
}

output "app_subnet_cidr" {
  description = "CIDR range of the app subnet."
  value       = google_compute_subnetwork.app.ip_cidr_range
}

output "app_service_account_email" {
  description = "Service account the app VM runs as."
  value       = google_service_account.app.email
}
