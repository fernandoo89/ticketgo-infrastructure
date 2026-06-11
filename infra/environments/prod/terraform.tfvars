###############################################################################
# terraform.tfvars — Valores específicos del entorno de producción
# ⚠️  NO commitear valores sensibles (db_username) — usar CI/CD secrets o
#     AWS Secrets Manager con `-var` en el pipeline.
###############################################################################

aws_region   = "us-east-1"
environment  = "prod"
project_name = "ticketgo"

# Networking
vpc_cidr                  = "10.0.0.0/16"
availability_zones        = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs       = ["10.0.1.0/24", "10.0.2.0/24"]
private_app_subnet_cidrs  = ["10.0.11.0/24", "10.0.12.0/24"]
private_data_subnet_cidrs = ["10.0.21.0/24", "10.0.22.0/24"]

# Database
db_instance_class        = "db.r6g.large"
db_name                  = "ticketgo_db"
db_username              = "ticketgo_admin"   # Sobrescribir desde CI/CD secret
db_allocated_storage     = 100
db_max_allocated_storage = 500

# Cache
redis_node_type       = "cache.r6g.large"
redis_num_cache_nodes = 2

# Compute — soporta hasta 5000 usuarios concurrentes con auto scaling
container_cpu      = 1024
container_memory   = 2048
ecs_desired_count  = 3
ecs_min_capacity   = 2
ecs_max_capacity   = 20
container_image    = "PLACEHOLDER_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/ticketgo-api:latest"

# Frontend
domain_name         = "ticketgo.pe"
acm_certificate_arn = "arn:aws:acm:us-east-1:PLACEHOLDER:certificate/PLACEHOLDER"

# Async
lambda_runtime         = "nodejs20.x"
sqs_visibility_timeout = 300
