###############################################################################
# modules/04-cache/main.tf
# Crea: ElastiCache Redis (Cluster Mode Disabled, Multi-AZ con failover)
#
# Decisiones de HA:
#  - Replication Group con automatic_failover_enabled: si el nodo primario
#    falla, uno de los réplicas es promovido automáticamente.
#  - at_rest_encryption y transit_encryption: datos cifrados en reposo y en
#    tránsito (TLS) — requerido para PCI DSS y mejores prácticas.
#  - Parámetro maxmemory-policy = allkeys-lru: en caso de memoria llena,
#    expulsa claves menos usadas recientemente, evitando errores de escritura.
###############################################################################

# ── Subnet Group ─────────────────────────────────────────────────────────────
resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}-redis-subnet-group"
  subnet_ids  = var.private_data_subnet_ids
  description = "Subnet group para Redis en subredes privadas de datos"

  tags = { Name = "${var.project_name}-${var.environment}-redis-subnet-group" }
}

# ── Parameter Group ───────────────────────────────────────────────────────────
resource "aws_elasticache_parameter_group" "redis" {
  family = "redis7"
  name   = "${var.project_name}-${var.environment}-redis7-params"
  description = "Parametros optimizados para cache de eventos TicketGo"

  # Política de evicción: elimina las claves menos usadas cuando la memoria
  # se llena. Crítico para un caché de catálogo de eventos (read-heavy).
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  # Notificaciones de eventos de keyspace (para invalidación proactiva de caché)
  parameter {
    name  = "notify-keyspace-events"
    value = "Ex"
  }

  tags = { Name = "${var.project_name}-${var.environment}-redis7-params" }
}

# ── Replication Group Redis ───────────────────────────────────────────────────
# Usamos Replication Group (no Cluster) para mantener compatibilidad con
# StackExchange.Redis y cliente Redis de ASP.NET Core sin configuración de shards.
resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project_name}-${var.environment}-redis"
  description          = "Redis cache para catalogo de eventos y sesiones - TicketGo"

  # Motor
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.redis_node_type
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  port                 = 6379

  # HA: num_cache_clusters = 1 primario + (num_cache_nodes - 1) réplicas
  num_cache_clusters         = var.redis_num_cache_nodes
  automatic_failover_enabled = true  # Promueve réplica si el primario falla

  # Multi-AZ automático cuando automatic_failover_enabled = true
  multi_az_enabled = true

  # Red y seguridad
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.sg_redis_id]

  # Cifrado — requerido para datos sensibles (tokens de sesión, caché de precios)
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  # Backup diario de Redis (instantáneas RDB para recuperación)
  snapshot_retention_limit = 7    # 7 días de snapshots
  snapshot_window          = "03:00-04:00"
  maintenance_window       = "sun:05:00-sun:06:00"

  # Parches automáticos de versiones menores
  auto_minor_version_upgrade = true

  # Protección contra borrado en producción
  final_snapshot_identifier = "${var.project_name}-${var.environment}-redis-final"

  apply_immediately = false  # Cambios en ventana de mantenimiento en producción

  tags = { Name = "${var.project_name}-${var.environment}-redis" }
}
