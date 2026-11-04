output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "web_subnet_id" {
  description = "ID of the web subnet."
  value       = aws_subnet.web.id
}

output "app_subnet_id" {
  description = "ID of the app subnet."
  value       = aws_subnet.app.id
}

output "db_subnet_ids" {
  description = "IDs of the database subnets."
  value       = aws_subnet.db[*].id
}

output "app_security_group_id" {
  description = "Firewall rule for the app tier."
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "Firewall rule for the database tier."
  value       = aws_security_group.db.id
}
