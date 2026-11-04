variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
}

variable "ami_id" {
  type        = string
  description = "Machine image for the instance."
}

variable "instance_type" {
  type        = string
  description = "Machine type for the instance."
}

variable "subnet_id" {
  type        = string
  description = "Subnet the instance runs in."
}

variable "security_group_id" {
  type        = string
  description = "Firewall rule attached to the instance."
}

variable "iam_instance_profile" {
  type        = string
  description = "Identity the instance runs as."
}
