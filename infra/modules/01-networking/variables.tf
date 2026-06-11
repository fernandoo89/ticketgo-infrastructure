###############################################################################
# modules/01-networking/variables.tf
###############################################################################

variable "project_name" {
  description = "Nombre del proyecto para prefijo de recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del entorno (prod, staging, dev)"
  type        = string
}

variable "aws_region" {
  description = "Región AWS donde se despliega la infraestructura"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block de la VPC"
  type        = string
}

variable "availability_zones" {
  description = "Lista de Availability Zones para Multi-AZ"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs para subredes públicas (ALB, NAT)"
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "CIDRs para subredes privadas de aplicación (ECS)"
  type        = list(string)
}

variable "private_data_subnet_cidrs" {
  description = "CIDRs para subredes privadas de datos (RDS, Redis)"
  type        = list(string)
}

variable "vpc_endpoint_sg_id" {
  description = "ID del Security Group para los VPC Interface Endpoints"
  type        = string
}
