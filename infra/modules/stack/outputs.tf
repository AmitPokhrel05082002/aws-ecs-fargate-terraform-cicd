output "app_url" {
  value = "${var.certificate_arn == "" ? "http" : "https"}://${module.service.alb_dns_name}"
}

output "ecs_cluster" {
  value = module.service.cluster_name
}

output "ecs_service" {
  value = module.service.service_name
}

output "task_family" {
  value = module.service.task_family
}

output "log_group" {
  value = module.service.log_group
}

output "bucket_name" {
  value = module.storage.bucket_name
}

output "db_address" {
  value = module.database.address
}

output "db_secret_arn" {
  value = module.database.master_user_secret_arn
}

output "kms_key_alias" {
  value = aws_kms_alias.this.name
}
