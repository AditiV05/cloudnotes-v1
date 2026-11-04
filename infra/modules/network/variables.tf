# The module's inputs. These are the only knobs a caller can turn.

variable "network_name" {
  type        = string
  description = "Name of the VPC. Also the prefix for the subnet and firewall rule names."
}

variable "cidr" {
  type        = string
  description = "CIDR range of the subnet (e.g. 10.0.2.0/24)."

  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "cidr must be a valid CIDR block."
  }
}

variable "region" {
  type        = string
  description = "GCP region of the subnet."
}

variable "allowed_ports" {
  type        = list(string)
  description = "TCP ports the firewall rule allows (e.g. [\"80\", \"443\"])."
}

variable "source_ranges" {
  type        = list(string)
  description = "Source CIDR ranges the firewall rule allows."
}

variable "target_tags" {
  type        = list(string)
  description = "Network tags of the instances the firewall rule applies to."
}
