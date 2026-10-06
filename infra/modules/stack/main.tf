# One complete environment. Staging and production both call this module with
# the same code; they differ only in the values in their terraform.tfvars
# (size, redundancy, retention). That is what keeps them in sync.

data "aws_caller_identity" "current" {}

data "aws_ecr_repository" "app" {
  name = var.project # created once by infra/bootstrap
}

locals {
  name = "${var.project}-${var.environment}"
}

# --- Encryption key for S3 and RDS (rotated yearly by AWS) --------------------
resource "aws_kms_key" "this" {
  description             = "${local.name} data encryption (S3, RDS)"
  enable_key_rotation     = true
  rotation_period_in_days = 365
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "this" {
  name          = "alias/${local.name}"
  target_key_id = aws_kms_key.this.key_id
}

# --- Network ------------------------------------------------------------------
module "network" {
  source = "../network"

  name               = local.name
  cidr               = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway
}

# --- Security groups: internet -> ALB -> app -> db only -----------------------
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "Public load balancer"
  vpc_id      = module.network.vpc_id
}

resource "aws_security_group" "app" {
  name        = "${local.name}-app"
  description = "ECS tasks, reachable only from the load balancer"
  vpc_id      = module.network.vpc_id
}

resource "aws_security_group" "db" {
  name        = "${local.name}-db"
  description = "RDS, reachable only from ECS tasks"
  vpc_id      = module.network.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward to ECS tasks"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Traffic from the load balancer"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound (ECR, Secrets Manager, S3, database) via NAT"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from ECS tasks"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# --- Data -----------------------------------------------------------------------
module "storage" {
  source = "../storage"

  bucket_name   = "${local.name}-assets-${data.aws_caller_identity.current.account_id}"
  kms_key_arn   = aws_kms_key.this.arn
  force_destroy = !var.protect_data
}

module "database" {
  source = "../database"

  name                  = local.name
  subnet_ids            = module.network.db_subnet_ids
  security_group_id     = aws_security_group.db.id
  kms_key_arn           = aws_kms_key.this.arn
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
  protect_data          = var.protect_data
}

# --- Application ------------------------------------------------------------------
module "service" {
  source = "../service"

  name                  = local.name
  region                = var.region
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  app_subnet_ids        = module.network.app_subnet_ids
  alb_security_group_id = aws_security_group.alb.id
  app_security_group_id = aws_security_group.app.id

  image          = "${data.aws_ecr_repository.app.repository_url}:${var.initial_image_tag}"
  container_port = var.container_port
  cpu            = var.task_cpu
  memory         = var.task_memory
  min_count      = var.min_tasks
  max_count      = var.max_tasks

  environment = {
    APP_ENV       = var.environment
    PORT          = tostring(var.container_port)
    AWS_REGION    = var.region
    DB_HOST       = module.database.address
    DB_PORT       = tostring(module.database.port)
    DB_NAME       = module.database.db_name
    DB_SECRET_ARN = module.database.master_user_secret_arn
    S3_BUCKET     = module.storage.bucket_name
  }

  db_secret_arn      = module.database.master_user_secret_arn
  bucket_arn         = module.storage.bucket_arn
  kms_key_arn        = aws_kms_key.this.arn
  certificate_arn    = var.certificate_arn
  log_retention_days = var.log_retention_days
  protect_resources  = var.protect_data
}
