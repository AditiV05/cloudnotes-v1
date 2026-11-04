output "instance_id" {
  description = "ID of the app instance."
  value       = aws_instance.app.id
}

output "private_ip" {
  description = "Private IP of the app instance."
  value       = aws_instance.app.private_ip
}
