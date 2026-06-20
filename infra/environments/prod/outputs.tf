###############################################################################
# environments/prod/outputs.tf — Salidas del entorno de producción
###############################################################################

# ── Networking ────────────────────────────────────────────────────────────────
output "vpc_id" {
  description = "ID de la VPC de producción"
  value       = module.networking.vpc_id
}

output "nat_gateway_public_ips" {
  description = "IPs públicas de los NAT Gateways (para whitelisting en firewalls externos)"
  value       = module.networking.nat_gateway_public_ips
}

# ── Compute ───────────────────────────────────────────────────────────────────
output "alb_dns_name" {
  description = "DNS del Application Load Balancer (apuntar registro DNS aquí)"
  value       = module.compute.alb_dns_name
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR para hacer docker push (usar en CI/CD)"
  value       = module.compute.ecr_repository_url
}

output "ecs_cluster_name" {
  description = "Nombre del cluster ECS para comandos de CLI"
  value       = module.compute.ecs_cluster_name
}

output "ecs_service_name" {
  description = "Nombre del servicio ECS para forzar nuevo despliegue"
  value       = module.compute.ecs_service_name
}

# ── Database ──────────────────────────────────────────────────────────────────
output "db_endpoint" {
  description = "Endpoint de escritura del RDS (NO usar directamente — usar secrets)"
  value       = module.database.db_endpoint
  sensitive   = true
}

# ── Cache ─────────────────────────────────────────────────────────────────────
output "redis_primary_endpoint" {
  description = "Endpoint primario de Redis"
  value       = module.cache.redis_primary_endpoint
  sensitive   = true
}

output "redis_reader_endpoint" {
  description = "Endpoint reader de Redis (balanceado entre réplicas)"
  value       = module.cache.redis_reader_endpoint
  sensitive   = true
}

# ── Frontend ──────────────────────────────────────────────────────────────────
output "cloudfront_domain_name" {
  description = "Dominio de CloudFront para el frontend (apuntar CNAME de DNS aquí)"
  value       = module.frontend.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "ID de CloudFront (usar en CI/CD para invalidar caché tras deploy)"
  value       = module.frontend.cloudfront_distribution_id
}

output "s3_frontend_bucket" {
  description = "Nombre del bucket S3 para subir el build del frontend"
  value       = module.frontend.s3_bucket_name
}

# ── Async ─────────────────────────────────────────────────────────────────────
output "sqs_queue_url" {
  description = "URL de la cola SQS de tickets (usar en la API para publicar mensajes)"
  value       = module.async.sqs_queue_url
}

output "lambda_function_name" {
  description = "Nombre de la Lambda worker (para desplegar código desde CI/CD)"
  value       = module.async.lambda_function_name
}

# ── Secrets ───────────────────────────────────────────────────────────────────
output "db_secret_arn" {
  description = "ARN del secreto de RDS en Secrets Manager"
  value       = module.security.db_secret_arn
}

# ── Summary ───────────────────────────────────────────────────────────────────
output "deployment_summary" {
  description = "Resumen de endpoints clave del despliegue"
  value = {
    frontend_url     = "https://${module.frontend.cloudfront_domain_name}"
    api_url          = "http://${module.compute.alb_dns_name}"
    ecr_repository   = module.compute.ecr_repository_url
    ecs_cluster      = module.compute.ecs_cluster_name
    s3_frontend      = module.frontend.s3_bucket_name
    cloudfront_id    = module.frontend.cloudfront_distribution_id
    lambda_worker    = module.async.lambda_function_name
    sqs_queue        = module.async.sqs_queue_url
  }
}
