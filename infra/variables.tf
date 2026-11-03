# Every environment-specific value is an input variable (values live in terraform.tfvars).

variable "project_id" {
  type        = string
  description = "GCP project ID that will own the CloudNotes resources."
}

variable "region" {
  type        = string
  description = "GCP region for regional resources (e.g. asia-south1)."
}

variable "zone" {
  type        = string
  description = "GCP zone for the app VM (must be inside var.region)."
}

variable "environment" {
  type        = string
  description = "Deployment environment, used in resource names and labels."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "app_subnet_cidr" {
  type        = string
  description = "CIDR range of the app subnet (e.g. 10.0.2.0/24)."

  validation {
    condition     = can(cidrhost(var.app_subnet_cidr, 0))
    error_message = "app_subnet_cidr must be a valid CIDR block."
  }
}

variable "web_source_ranges" {
  type        = list(string)
  description = "Source CIDR ranges allowed to reach HTTP/HTTPS (tcp:80,443)."
}

variable "admin_source_ranges" {
  type        = list(string)
  description = "Trusted source CIDR ranges allowed to SSH (tcp:22), e.g. IAP 35.235.240.0/20."

  validation {
    condition     = !contains(var.admin_source_ranges, "0.0.0.0/0")
    error_message = "SSH must never be open to 0.0.0.0/0."
  }
}

variable "machine_type" {
  type        = string
  description = "Compute Engine machine type for the app VM (e.g. e2-small)."
}

variable "boot_image" {
  type        = string
  description = "Boot image for the app VM (e.g. ubuntu-os-cloud/ubuntu-2404-lts-amd64)."
}

variable "boot_disk_size_gb" {
  type        = number
  description = "Boot disk size of the app VM in GB."
  default     = 20
}

variable "bucket_name" {
  type        = string
  description = "Globally unique name of the Cloud Storage bucket for CloudNotes assets."
}

variable "bucket_location" {
  type        = string
  description = "Location of the assets bucket (region or multi-region, e.g. ASIA-SOUTH1)."
}

variable "nearline_after_days" {
  type        = number
  description = "Age in days after which assets move to the NEARLINE storage class."
  default     = 30
}

variable "labels" {
  type        = map(string)
  description = "Extra labels applied to labelled resources."
  default     = {}
}

variable "access_token" {
  type        = string
  description = "OAuth token for the google provider. A placeholder is enough for offline plan (never apply)."
  sensitive   = true
  default     = "offline-plan-only"
}
