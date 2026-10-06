# Identical in every environment. Set values in terraform.tfvars.

variable "project" {
  description = "Must match the project name used in infra/bootstrap."
  type        = string
}

variable "environment" {
  description = "Must match the GitHub environment name (staging or production)."
  type        = string
}

variable "region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "single_nat_gateway" {
  type = bool
}

variable "task_cpu" {
  type = number
}

variable "task_memory" {
  type = number
}

variable "min_tasks" {
  type = number
}

variable "max_tasks" {
  type = number
}

variable "db_instance_class" {
  type = string
}

variable "db_allocated_storage" {
  type = number
}

variable "db_multi_az" {
  type = bool
}

variable "db_backup_retention_days" {
  type = number
}

variable "log_retention_days" {
  type = number
}

variable "protect_data" {
  type = bool
}

variable "certificate_arn" {
  description = "ACM certificate for HTTPS. Empty = HTTP only."
  type        = string
  default     = ""
}
