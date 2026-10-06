# Staging: same architecture as production, smaller and cheaper.
project     = "sample-saas"
environment = "staging"
region      = "ap-southeast-1"

vpc_cidr           = "10.10.0.0/16"
single_nat_gateway = true

task_cpu    = 256
task_memory = 512
min_tasks   = 1
max_tasks   = 2

db_instance_class        = "db.t4g.micro"
db_allocated_storage     = 20
db_multi_az              = false
db_backup_retention_days = 1

log_retention_days = 14
protect_data       = false
