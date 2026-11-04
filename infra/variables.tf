# Every environment-specific value is declared here, once. Modules stay generic.

variable "region" {
  type        = string
  description = "Region for all CloudNotes resources."
}

variable "availability_zones" {
  type        = list(string)
  description = "Two zones. The first holds the web and app subnets, and the database uses both."
}

variable "localstack_endpoint" {
  type        = string
  description = "LocalStack URL the provider talks to."
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names, for example cloudnotes-dev."
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
  description = "CIDR ranges of the two database subnets."
}

variable "web_source_ranges" {
  type        = list(string)
  description = "Source ranges allowed into the web tier on HTTPS."
}

variable "app_port" {
  type        = number
  description = "Port the CloudNotes app listens on."
}

variable "db_port" {
  type        = number
  description = "Port the database listens on."
}

variable "ami_id" {
  type        = string
  description = "Machine image for the app instance."
}

variable "instance_type" {
  type        = string
  description = "Machine type for the app instance."
}

variable "db_engine_version" {
  type        = string
  description = "PostgreSQL major version."
}

variable "db_instance_class" {
  type        = string
  description = "Machine class for the managed database."
}

variable "db_allocated_storage" {
  type        = number
  description = "Database storage in GB."
}

variable "db_name" {
  type        = string
  description = "Name of the CloudNotes database."
}

variable "db_username" {
  type        = string
  description = "Database admin username. The password is generated and managed by the cloud, never stored here."
}

variable "bucket_name" {
  type        = string
  description = "Name of the assets bucket."
}
