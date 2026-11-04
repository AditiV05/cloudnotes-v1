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

output "web_network_id" {
  description = "ID of the web VPC, read from the network module."
  value       = module.web_network.network_id
}

output "web_subnet_cidr" {
  description = "CIDR range of the web subnet, read from the network module."
  value       = module.web_network.subnet_cidr
}

output "app_network_name" {
  description = "Name of the app VPC, read from the network module."
  value       = module.app_network.network_name
}

output "app_subnet_id" {
  description = "ID of the app subnet, read from the network module."
  value       = module.app_network.subnet_id
}

output "app_service_account_email" {
  description = "Service account the app VM runs as."
  value       = google_service_account.app.email
}
