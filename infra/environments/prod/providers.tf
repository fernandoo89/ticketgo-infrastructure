###############################################################################
# providers.tf — Configuración del provider AWS y backend remoto en S3
# Decisión: Usamos S3 + DynamoDB como backend para state locking en equipo.
###############################################################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Backend remoto: el bucket y la tabla DynamoDB deben pre-existir
  # (bootstrapear una sola vez con `terraform init` en un entorno limpio)
  backend "s3" {
    bucket         = "http://ticketgo-tfstate-prod-1781628388.s3.amazonaws.com/" # Cambiar por nombre real del bucket
    key            = "prod/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true                              # AES-256 en reposo
    dynamodb_table = "ticketgo-tfstate-lock"           # Tabla para state locking
  }
}

# Provider principal — región primaria de producción
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "TicketGo-Peru"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "infra-team"
    }
  }
}

# Provider secundario: us-east-1 requerido por CloudFront + WAF (siempre global)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "TicketGo-Peru"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "infra-team"
    }
  }
}
