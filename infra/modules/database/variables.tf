variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
}

variable "engine_version" {
  type        = string
  description = "PostgreSQL major version."
}

variable "instance_class" {
  type        = string
  description = "Machine class for the database."
}

variable "allocated_storage" {
  type        = number
  description = "Storage in GB."
}

variable "db_name" {
  type        = string
  description = "Name of the database."
}

variable "db_username" {
  type        = string
  description = "Admin username."
}

variable "db_port" {
  type        = number
  description = "Port the database listens on."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnets for the database."
}

variable "security_group_id" {
  type        = string
  description = "Firewall rule attached to the database."
}
