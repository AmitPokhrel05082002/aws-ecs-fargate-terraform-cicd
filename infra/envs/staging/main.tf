# This file is identical in every environment (CI checks this).
# Environment differences live only in terraform.tfvars.
#
# The state bucket, key and region come from `make init ENV=<env>`:
#   -backend-config="bucket=<project>-tfstate-<account-id>"
#   -backend-config="key=<env>/terraform.tfstate"
#   -backend-config="region=<region>"

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    encrypt      = true
    use_lockfile = true # native S3 state locking (Terraform >= 1.10)
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

module "stack" {
  source = "../../modules/stack"

  project     = var.project
  environment = var.environment
  region      = var.region

  vpc_cidr           = var.vpc_cidr
  single_nat_gateway = var.single_nat_gateway

  task_cpu    = var.task_cpu
  task_memory = var.task_memory
  min_tasks   = var.min_tasks
  max_tasks   = var.max_tasks

  db_instance_class        = var.db_instance_class
  db_allocated_storage     = var.db_allocated_storage
  db_multi_az              = var.db_multi_az
  db_backup_retention_days = var.db_backup_retention_days

  log_retention_days = var.log_retention_days
  protect_data       = var.protect_data
  certificate_arn    = var.certificate_arn
}

output "app_url" {
  value = module.stack.app_url
}

output "ecs_cluster" {
  value = module.stack.ecs_cluster
}

output "ecs_service" {
  value = module.stack.ecs_service
}

output "log_group" {
  value = module.stack.log_group
}

output "bucket_name" {
  value = module.stack.bucket_name
}

output "db_secret_arn" {
  value = module.stack.db_secret_arn
}
