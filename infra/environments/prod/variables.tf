###############################################################################
# variables.tf — Variables del entorno de producción
###############################################################################

# ── General ──────────────────────────────────────────────────────────────────
variable "aws_region" {
  description = "Región AWS principal de despliegue"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Nombre del entorno (prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Nombre del proyecto usado como prefijo de recursos"
  type        = string
  default     = "ticketgo"
}

# ── Networking ────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block de la VPC principal"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Lista de AZs a usar para alta disponibilidad (Multi-AZ)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs para subredes públicas (ALB, NAT Gateway)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDRs para subredes privadas de aplicación (ECS Fargate)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_data_subnet_cidrs" {
  description = "CIDRs para subredes privadas de datos (RDS, ElastiCache)"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

# ── Database (RDS PostgreSQL) ─────────────────────────────────────────────────
variable "db_instance_class" {
  description = "Tipo de instancia RDS para producción"
  type        = string
  default     = "db.r6g.large"
}

variable "db_name" {
  description = "Nombre de la base de datos inicial en RDS"
  type        = string
  default     = "ticketgo_db"
}

variable "db_username" {
  description = "Usuario maestro de RDS (almacenado en Secrets Manager)"
  type        = string
  sensitive   = true
}

variable "db_allocated_storage" {
  description = "Almacenamiento inicial de RDS en GB"
  type        = number
  default     = 100
}

variable "db_max_allocated_storage" {
  description = "Almacenamiento máximo con autoscaling de RDS en GB"
  type        = number
  default     = 500
}

# ── Cache (ElastiCache Redis) ─────────────────────────────────────────────────
variable "redis_node_type" {
  description = "Tipo de nodo Redis para ElastiCache"
  type        = string
  default     = "cache.r6g.large"
}

variable "redis_num_cache_nodes" {
  description = "Número de nodos en el cluster Redis"
  type        = number
  default     = 2
}

# ── Compute (ECS Fargate) ─────────────────────────────────────────────────────
variable "container_image" {
  description = "URI de la imagen Docker en ECR (ej: 123456789.dkr.ecr.us-east-1.amazonaws.com/ticketgo-api:latest)"
  type        = string
}

variable "container_cpu" {
  description = "CPU en unidades vCPU para el contenedor Fargate (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "container_memory" {
  description = "Memoria en MB para el contenedor Fargate"
  type        = number
  default     = 2048
}

variable "ecs_desired_count" {
  description = "Número inicial de tareas ECS en producción"
  type        = number
  default     = 3
}

variable "ecs_min_capacity" {
  description = "Mínimo de tareas ECS en auto scaling"
  type        = number
  default     = 2
}

variable "ecs_max_capacity" {
  description = "Máximo de tareas ECS en auto scaling (para picos de 5000 usuarios)"
  type        = number
  default     = 20
}

# ── Frontend ──────────────────────────────────────────────────────────────────
variable "domain_name" {
  description = "Nombre de dominio principal de la aplicación (ej: ticketgo.pe)"
  type        = string
  default     = "ticketgo.pe"
}

variable "acm_certificate_arn" {
  description = "ARN del certificado ACM en us-east-1 para CloudFront"
  type        = string
  default     = ""
}

# ── Async (Lambda + SQS) ─────────────────────────────────────────────────────
variable "lambda_runtime" {
  description = "Runtime de Lambda para el worker de tickets"
  type        = string
  default     = "nodejs20.x"
}

variable "sqs_visibility_timeout" {
  description = "Tiempo de visibilidad de mensajes SQS en segundos"
  type        = number
  default     = 300
}
