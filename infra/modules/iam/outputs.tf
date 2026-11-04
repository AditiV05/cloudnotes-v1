output "app_role_arn" {
  description = "ARN of the app's role."
  value       = aws_iam_role.app.arn
}

output "app_instance_profile_name" {
  description = "Instance profile that gives the VM this identity."
  value       = aws_iam_instance_profile.app.name
}
