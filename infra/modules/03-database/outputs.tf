###############################################################################
# modules/03-database/outputs.tf
###############################################################################

output "db_instance_id" {
  description = "ID de la instancia RDS primaria"
  value       = aws_db_instance.primary.id
}

output "db_endpoint" {
  description = "Endpoint de conexión al RDS primario (escritura)"
  value       = aws_db_instance.primary.endpoint
}

output "db_port" {
  description = "Puerto de conexión RDS"
  value       = aws_db_instance.primary.port
}

output "db_name" {
  description = "Nombre de la base de datos"
  value       = aws_db_instance.primary.db_name
}

output "db_arn" {
  description = "ARN de la instancia RDS primaria"
  value       = aws_db_instance.primary.arn
}

output "backup_vault_name" {
  description = "Nombre del vault de AWS Backup"
  value       = aws_backup_vault.main.name
}

output "backup_plan_id" {
  description = "ID del plan de backup de RDS"
  value       = aws_backup_plan.rds.id
}

output "kms_key_arn" {
  description = "ARN de la KMS Key usada para el vault de backup"
  value       = var.kms_key_arn != "" ? var.kms_key_arn : aws_kms_key.backup[0].arn
}
