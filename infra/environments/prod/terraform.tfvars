###############################################################################
# terraform.tfvars — Valores específicos del entorno de producción
# ⚠️  NO commitear valores sensibles (db_username) — usar CI/CD secrets o
#     AWS Secrets Manager con `-var` en el pipeline.
###############################################################################

aws_region   = "us-east-2"
environment  = "prod"
project_name = "ticketgo"

# Networking
vpc_cidr                  = "10.0.0.0/16"
availability_zones        = ["us-east-2a", "us-east-2b"]
public_subnet_cidrs       = ["10.0.1.0/24", "10.0.2.0/24"]
private_app_subnet_cidrs  = ["10.0.11.0/24", "10.0.12.0/24"]
private_data_subnet_cidrs = ["10.0.21.0/24", "10.0.22.0/24"]

# Database
db_instance_class        = "db.t4g.micro"
db_name                  = "ticketgo_db"
db_username              = "ticketgo_admin"   # Sobrescribir desde CI/CD secret
db_allocated_storage     = 20
db_max_allocated_storage = 100

# Cache
redis_node_type       = "cache.t4g.micro"
redis_num_cache_nodes = 1

# Compute — Modo Pruebas Low-Cost
container_cpu      = 256
container_memory   = 512
ecs_desired_count  = 1
ecs_min_capacity   = 1
ecs_max_capacity   = 2
container_image    = "PLACEHOLDER_ACCOUNT.dkr.ecr.us-east-2.amazonaws.com/ticketgo-api:latest"

# Frontend
domain_name         = ""
acm_certificate_arn = ""

# Async
lambda_runtime         = "nodejs20.x"
sqs_visibility_timeout = 300
sender_email           = "notificaciones@ticketgo.pe"
