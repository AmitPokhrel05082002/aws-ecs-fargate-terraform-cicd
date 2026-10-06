variable "bucket_name" {
  description = "Globally unique bucket name."
  type        = string
}

variable "kms_key_arn" {
  description = "Customer managed KMS key used for default encryption."
  type        = string
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete a non-empty bucket."
  type        = bool
  default     = false
}

variable "noncurrent_version_days" {
  description = "Days to keep overwritten or deleted object versions."
  type        = number
  default     = 30
}
