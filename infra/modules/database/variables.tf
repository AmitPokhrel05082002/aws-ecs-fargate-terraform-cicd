variable "name" {
  type = string
}

variable "subnet_ids" {
  description = "Private db subnets (at least two AZs)."
  type        = list(string)
}

variable "security_group_id" {
  type = string
}

variable "kms_key_arn" {
  description = "KMS key for storage encryption."
  type        = string
}

variable "engine_major_version" {
  type    = string
  default = "16"
}

variable "instance_class" {
  type = string
}

variable "allocated_storage" {
  description = "Initial storage in GiB. Storage autoscaling grows up to 4x this."
  type        = number
}

variable "db_name" {
  type    = string
  default = "app"
}

variable "master_username" {
  type    = string
  default = "app_admin"
}

variable "multi_az" {
  type = bool
}

variable "backup_retention_days" {
  type = number
}

variable "protect_data" {
  description = "Enables deletion protection and a final snapshot. Set true for production."
  type        = bool
}
