variable "project" {
  description = "Short lowercase project name. Used in resource names, so it must match infra/envs/*/terraform.tfvars."
  type        = string
  default     = "sample-saas"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project))
    error_message = "Use 3-21 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "ap-southeast-1"
}

variable "github_repo" {
  description = "GitHub repository allowed to deploy, as owner/name (for example amitsharma/aws-ecs-fargate-terraform-cicd)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repo))
    error_message = "Use the form owner/repository."
  }
}

variable "environments" {
  description = "GitHub environment names. Each one gets its own deploy role and must match a folder in infra/envs."
  type        = list(string)
  default     = ["staging", "production"]
}

variable "images_to_keep" {
  description = "How many images ECR keeps before expiring the oldest."
  type        = number
  default     = 30
}

variable "allow_destroy" {
  description = "Allow terraform destroy to delete the ECR repository even if it still holds images."
  type        = bool
  default     = false
}
