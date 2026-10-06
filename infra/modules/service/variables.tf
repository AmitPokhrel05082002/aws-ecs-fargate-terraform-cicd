variable "name" {
  description = "Name used for the cluster, service, task family, load balancer and roles (project-environment)."
  type        = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "app_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "app_security_group_id" {
  type = string
}

variable "image" {
  description = "Initial container image (repository:tag). Later deploys are done by GitHub Actions."
  type        = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)."
  type        = number
}

variable "memory" {
  description = "Fargate task memory in MiB."
  type        = number
}

variable "min_count" {
  type = number
}

variable "max_count" {
  type = number
}

variable "cpu_target_percent" {
  description = "Average CPU that autoscaling tries to hold."
  type        = number
  default     = 60
}

variable "environment" {
  description = "Plain (non-secret) environment variables for the container."
  type        = map(string)
  default     = {}
}

variable "db_secret_arn" {
  description = "Secrets Manager secret the app reads its database credentials from."
  type        = string
}

variable "bucket_arn" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Leave empty for HTTP only."
  type        = string
  default     = ""
}

variable "log_retention_days" {
  type = number
}

variable "protect_resources" {
  description = "Enable deletion protection on the load balancer."
  type        = bool
  default     = false
}
