variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
}

variable "bucket_arn" {
  type        = string
  description = "ARN of the only bucket the app may access."
}
