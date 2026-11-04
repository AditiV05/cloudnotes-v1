output "vpc_id" {
  description = "ID of the CloudNotes VPC."
  value       = module.network.vpc_id
}

output "app_private_ip" {
  description = "Private IP of the app instance."
  value       = module.compute.private_ip
}

output "db_endpoint" {
  description = "Connection endpoint of the database."
  value       = module.database.endpoint
}

output "db_name" {
  description = "Name of the CloudNotes database."
  value       = module.database.db_name
}

output "bucket_name" {
  description = "Name of the assets bucket."
  value       = module.storage.bucket_name
}

output "app_role_arn" {
  description = "ARN of the app's identity (IAM role)."
  value       = module.iam.app_role_arn
}
