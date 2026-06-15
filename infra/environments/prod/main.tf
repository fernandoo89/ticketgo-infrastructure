###############################################################################
# environments/prod/main.tf
# Entorno de Producción — Orquesta todos los módulos de TicketGo Perú
#
# Orden de dependencias:
#  01-networking → 02-security → 03-database
#                             → 04-cache
#                             → 05-compute (necesita DB + cache endpoints)
#                             → 06-async
#  07-frontend es independiente (solo necesita el provider us_east_1)
###############################################################################

# ── Datos del contexto AWS ────────────────────────────────────────────────────
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── IAM Role para RDS Enhanced Monitoring ─────────────────────────────────────
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

###############################################################################
# MÓDULO 01 — Networking
# Crea la VPC, todas las subnets y NAT Gateways
###############################################################################
module "networking" {
  source = "../../modules/01-networking"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  vpc_cidr                  = var.vpc_cidr
  availability_zones        = var.availability_zones
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs

  # El SG de VPC Endpoints lo crea el módulo de seguridad (orden: security después)
  # Se usa depends_on para garantizar orden correcto
  vpc_endpoint_sg_id = module.security.sg_vpc_endpoints_id
}

###############################################################################
# MÓDULO 02 — Security
# Security Groups + IAM Roles + Secrets Manager
###############################################################################
module "security" {
  source = "../../modules/02-security"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  vpc_id         = module.networking.vpc_id
  vpc_cidr       = module.networking.vpc_cidr_block
  container_port = 8080

  db_username = var.db_username
  db_name     = var.db_name

  # El endpoint de RDS se conoce después de crear la DB — se actualiza con null_resource
  # El secreto inicial tendrá un placeholder que el módulo de DB actualiza
  db_endpoint = "INITIAL_PLACEHOLDER"

  depends_on = [module.networking]
}

###############################################################################
# MÓDULO 03 — Database (RDS PostgreSQL Multi-AZ)
###############################################################################
module "database" {
  source = "../../modules/03-database"

  project_name = var.project_name
  environment  = var.environment

  private_data_subnet_ids = module.networking.private_data_subnet_ids
  sg_rds_id               = module.security.sg_rds_id

  db_instance_class        = var.db_instance_class
  db_name                  = var.db_name
  db_username              = var.db_username
  db_password              = module.security.db_password   # Generado por random_password
  db_allocated_storage     = var.db_allocated_storage
  db_max_allocated_storage = var.db_max_allocated_storage

  rds_monitoring_role_arn = aws_iam_role.rds_monitoring.arn
  backup_role_arn         = module.security.backup_role_arn

  depends_on = [module.security]
}

###############################################################################
# MÓDULO 04 — Cache (ElastiCache Redis)
###############################################################################
module "cache" {
  source = "../../modules/04-cache"

  project_name = var.project_name
  environment  = var.environment

  private_data_subnet_ids = module.networking.private_data_subnet_ids
  sg_redis_id             = module.security.sg_redis_id

  redis_node_type       = var.redis_node_type
  redis_num_cache_nodes = var.redis_num_cache_nodes

  depends_on = [module.security]
}

###############################################################################
# MÓDULO 05 — Compute (ECR, ECS Fargate, ALB, Auto Scaling)
###############################################################################
module "compute" {
  source = "../../modules/05-compute"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  vpc_id                 = module.networking.vpc_id
  public_subnet_ids      = module.networking.public_subnet_ids
  private_app_subnet_ids = module.networking.private_app_subnet_ids

  sg_alb_id = module.security.sg_alb_id
  sg_ecs_id = module.security.sg_ecs_id

  container_image  = var.container_image
  container_port   = 8080
  container_cpu    = var.container_cpu
  container_memory = var.container_memory

  ecs_desired_count = var.ecs_desired_count
  ecs_min_capacity  = var.ecs_min_capacity
  ecs_max_capacity  = var.ecs_max_capacity

  ecs_task_execution_role_arn = module.security.ecs_task_execution_role_arn
  ecs_task_role_arn           = module.security.ecs_task_role_arn

  # Credenciales inyectadas desde Secrets Manager (no hardcodeadas)
  db_secret_arn            = module.security.db_secret_arn
  redis_primary_endpoint   = module.cache.redis_primary_endpoint

  acm_certificate_arn = var.acm_certificate_arn

  depends_on = [module.database, module.cache]
}

###############################################################################
# MÓDULO 06 — Async (SQS + Lambda Worker)
###############################################################################
module "async" {
  source = "../../modules/06-async"

  project_name = var.project_name
  environment  = var.environment

  private_app_subnet_ids = module.networking.private_app_subnet_ids
  sg_lambda_id           = module.security.sg_lambda_id

  lambda_worker_role_arn = module.security.lambda_worker_role_arn
  lambda_runtime         = var.lambda_runtime

  db_secret_arn          = module.security.db_secret_arn
  sqs_visibility_timeout = var.sqs_visibility_timeout
  sender_email           = var.sender_email

  depends_on = [module.security]
}

###############################################################################
# MÓDULO 07 — Frontend (S3 + CloudFront + WAF)
# Nota: el provider us_east_1 es requerido por WAF CLOUDFRONT
###############################################################################
module "frontend" {
  source = "../../modules/07-frontend"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project_name = var.project_name
  environment  = var.environment

  domain_name         = var.domain_name
  acm_certificate_arn = var.acm_certificate_arn
}

###############################################################################
# Actualización del Secreto de DB con el endpoint real post-creación
###############################################################################
resource "aws_secretsmanager_secret_version" "db_credentials_final" {
  secret_id = module.security.db_secret_arn

  secret_string = jsonencode({
    username = var.db_username
    password = module.security.db_password
    host     = split(":", module.database.db_endpoint)[0]  # Extrae solo el host
    port     = 5432
    dbname   = var.db_name
  })

  depends_on = [module.database]
}

# Actualización del Secreto Redis con el endpoint real
resource "aws_secretsmanager_secret_version" "redis_url_final" {
  secret_id = module.security.redis_secret_arn

  secret_string = jsonencode({
    primary_endpoint = module.cache.redis_primary_endpoint
    reader_endpoint  = module.cache.redis_reader_endpoint
    port             = module.cache.redis_port
    # URL de conexión para StackExchange.Redis (ASP.NET Core)
    connection_string = "${module.cache.redis_primary_endpoint}:${module.cache.redis_port},ssl=true,abortConnect=false"
  })

  depends_on = [module.cache]
}
