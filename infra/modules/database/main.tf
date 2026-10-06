# PostgreSQL on RDS in the private db subnets.
# The master password is generated and stored by RDS in AWS Secrets Manager
# and rotated automatically, so no password ever appears in Terraform state,
# code or CI variables.

resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-pg${var.engine_major_version}"
  family = "postgres${var.engine_major_version}"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # log queries slower than 1s
  }
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = var.engine_major_version

  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 4
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_name                     = var.db_name
  username                    = var.master_username
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period    = var.backup_retention_days
  copy_tags_to_snapshot      = true
  deletion_protection        = var.protect_data
  skip_final_snapshot        = !var.protect_data
  final_snapshot_identifier  = var.protect_data ? "${var.name}-final" : null
  auto_minor_version_upgrade = true
  apply_immediately          = !var.protect_data

  enabled_cloudwatch_logs_exports = ["postgresql"]
}
