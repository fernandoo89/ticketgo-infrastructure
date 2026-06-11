###############################################################################
# modules/05-compute/outputs.tf
###############################################################################

output "ecr_repository_url" {
  description = "URL del repositorio ECR para hacer push de imágenes"
  value       = aws_ecr_repository.api.repository_url
}

output "ecs_cluster_name" {
  description = "Nombre del cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN del cluster ECS"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_service_name" {
  description = "Nombre del servicio ECS"
  value       = aws_ecs_service.api.name
}

output "alb_dns_name" {
  description = "DNS name del Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN del ALB"
  value       = aws_lb.main.arn
}

output "alb_zone_id" {
  description = "Zone ID del ALB para registros Route53 Alias"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "ARN del Target Group del ALB"
  value       = aws_lb_target_group.api.arn
}
