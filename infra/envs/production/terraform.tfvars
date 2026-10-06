# Production: highly available (NAT per AZ, Multi-AZ RDS, 2+ tasks) and protected.
project     = "sample-saas"
environment = "production"
region      = "ap-southeast-1"

vpc_cidr           = "10.20.0.0/16"
single_nat_gateway = false

task_cpu    = 512
task_memory = 1024
min_tasks   = 2
max_tasks   = 6

db_instance_class        = "db.t4g.small"
db_allocated_storage     = 50
db_multi_az              = true
db_backup_retention_days = 14

log_retention_days = 90
protect_data       = true

# certificate_arn = "arn:aws:acm:ap-southeast-1:123456789012:certificate/..."
