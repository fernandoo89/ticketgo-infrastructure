###############################################################################
# modules/02-security/outputs.tf
###############################################################################

output "sg_alb_id" {
  description = "ID del Security Group del ALB"
  value       = aws_security_group.alb.id
}

output "sg_ecs_id" {
  description = "ID del Security Group de ECS Fargate"
  value       = aws_security_group.ecs.id
}

output "sg_rds_id" {
  description = "ID del Security Group de RDS"
  value       = aws_security_group.rds.id
}

output "sg_redis_id" {
  description = "ID del Security Group de ElastiCache Redis"
  value       = aws_security_group.redis.id
}

output "sg_lambda_id" {
  description = "ID del Security Group de Lambda"
  value       = aws_security_group.lambda.id
}

output "sg_vpc_endpoints_id" {
  description = "ID del Security Group de VPC Interface Endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "ecs_task_execution_role_arn" {
  description = "ARN del IAM Role de ejecución de tareas ECS"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN del IAM Role de la tarea ECS (runtime)"
  value       = aws_iam_role.ecs_task.arn
}

output "lambda_worker_role_arn" {
  description = "ARN del IAM Role del Lambda worker"
  value       = aws_iam_role.lambda_worker.arn
}

output "backup_role_arn" {
  description = "ARN del IAM Role para AWS Backup"
  value       = aws_iam_role.backup.arn
}

output "db_secret_arn" {
  description = "ARN del secreto de credenciales de RDS en Secrets Manager"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_password" {
  description = "Contraseña generada para RDS (solo para referencia interna)"
  value       = random_password.db_password.result
  sensitive   = true
}

output "redis_secret_arn" {
  description = "ARN del secreto de URL Redis en Secrets Manager"
  value       = aws_secretsmanager_secret.redis_url.arn
}
