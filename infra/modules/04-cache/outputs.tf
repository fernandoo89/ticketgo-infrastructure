###############################################################################
# modules/04-cache/outputs.tf
###############################################################################

output "redis_primary_endpoint" {
  description = "Endpoint del nodo primario Redis (lectura/escritura)"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Endpoint del reader Redis (solo lectura, balanceado entre réplicas)"
  value       = aws_elasticache_replication_group.main.reader_endpoint_address
}

output "redis_port" {
  description = "Puerto de Redis"
  value       = aws_elasticache_replication_group.main.port
}

output "redis_replication_group_id" {
  description = "ID del Replication Group de Redis"
  value       = aws_elasticache_replication_group.main.id
}
