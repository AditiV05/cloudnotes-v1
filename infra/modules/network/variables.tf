variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR range of the VPC."
}

variable "web_subnet_cidr" {
  type        = string
  description = "CIDR range of the web subnet."
}

variable "app_subnet_cidr" {
  type        = string
  description = "CIDR range of the app subnet."
}

variable "db_subnet_cidrs" {
  type        = list(string)
  description = "CIDR ranges of the database subnets, one per zone."

  validation {
    condition     = length(var.db_subnet_cidrs) >= 2
    error_message = "A managed database needs at least two subnets."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "Zones for the subnets."
}

variable "web_source_ranges" {
  type        = list(string)
  description = "Source ranges allowed into the web tier."
}

variable "app_port" {
  type        = number
  description = "Port the app listens on."
}

variable "db_port" {
  type        = number
  description = "Port the database listens on."
}
