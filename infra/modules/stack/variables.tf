variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "az_count" {
  type    = number
  default = 2
}

variable "single_nat_gateway" {
  type = bool
}

variable "initial_image_tag" {
  description = "Image tag used only when the service is first created. After that, GitHub Actions deploys images."
  type        = string
  default     = "initial"
}

variable "container_port" {
  type    = number
  default = 8080
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
  description = "Deletion protection on RDS and the load balancer, final DB snapshot, and no force-destroy on S3."
  type        = bool
}

variable "certificate_arn" {
  type    = string
  default = ""
}
