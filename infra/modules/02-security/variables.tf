###############################################################################
# modules/02-security/variables.tf
###############################################################################

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se crean los Security Groups"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR de la VPC para reglas de SG de VPC Endpoints"
  type        = string
}

variable "container_port" {
  description = "Puerto que expone el contenedor ASP.NET Core"
  type        = number
  default     = 8080
}

variable "db_username" {
  description = "Usuario maestro de RDS"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
}

variable "db_endpoint" {
  description = "Endpoint de RDS (disponible post-creación)"
  type        = string
  default     = "PLACEHOLDER_WILL_BE_UPDATED"
}
