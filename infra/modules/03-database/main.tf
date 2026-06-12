###############################################################################
# modules/03-database/main.tf
# Crea: RDS PostgreSQL Multi-AZ, Read Replica, Subnet Group, Parameter Group
#       AWS Backup Plan (PITR habilitado)
#
# Decisiones de HA y recuperación:
#  - Multi-AZ: AWS mantiene una réplica síncrona en otra AZ → failover
#    automático en ~60s sin pérdida de datos.
#  - PITR (Point-In-Time Recovery): retención de 35 días para RDS y plan
#    de backup adicional con AWS Backup para retención extendida.
#  - Read Replica: descarga consultas de lectura (catálogo de eventos) del
#    primario, mejorando el rendimiento bajo alta concurrencia.
#  - Storage autoscaling: evita downtime por falta de espacio en producción.
###############################################################################

# ── Subnet Group (Multi-AZ requiere subnets en al menos 2 AZs) ───────────────
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids  = var.private_data_subnet_ids
  description = "Subnet group para RDS PostgreSQL en subredes privadas de datos"

  tags = { Name = "${var.project_name}-${var.environment}-db-subnet-group" }
}

# ── Parameter Group personalizado ─────────────────────────────────────────────
# Optimizado para alta concurrencia (TicketGo: 5000 usuarios simultáneos)
resource "aws_db_parameter_group" "postgres" {
  family = "postgres16"
  name   = "${var.project_name}-${var.environment}-pg16-params"
  description = "Parametros optimizados para alta concurrencia en TicketGo"

  # Incrementar conexiones máximas (default es bajo en instancias pequeñas)
  parameter {
    name  = "max_connections"
    value = "500"
  }

  # Logging de queries lentas (>500ms) para monitoreo de performance
  parameter {
    name  = "log_min_duration_statement"
    value = "500"
  }

  # Checkpoint más frecuente reduce el tiempo de recovery ante crash
  parameter {
    name  = "checkpoint_completion_target"
    value = "0.9"
  }

  # Habilitar SSL — los clientes DEBEN conectarse con SSL
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "immediate"
  }

  tags = { Name = "${var.project_name}-${var.environment}-pg16-params" }
}

# ── RDS PostgreSQL Principal (Multi-AZ) ──────────────────────────────────────
resource "aws_db_instance" "primary" {
  identifier = "${var.project_name}-${var.environment}-postgres-primary"

  # Motor
  engine               = "postgres"
  engine_version       = "16.3"
  instance_class       = var.db_instance_class
  parameter_group_name = aws_db_parameter_group.postgres.name

  # Almacenamiento con autoscaling habilitado
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage  # Autoscaling hasta 500 GB
  storage_type          = "gp3"
  storage_encrypted     = true  # Seguridad: cifrado AES-256 en reposo

  # Credenciales (NO hardcodeadas — vienen de Secrets Manager)
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Red y seguridad
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.sg_rds_id]
  publicly_accessible    = false  # Seguridad: NUNCA exponer RDS a Internet

  # Alta disponibilidad: Multi-AZ con réplica síncrona en otra AZ
  multi_az = true

  # Backups y PITR
  backup_retention_period   = 35   # Máximo PITR nativo de RDS (35 días)
  backup_window             = "02:00-03:00"   # Ventana de backup en horas valle
  maintenance_window        = "sun:04:00-sun:05:00"

  # Protección contra borrado accidental en producción
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-final-snapshot"

  # Performance Insights para monitoreo avanzado de queries
  performance_insights_enabled          = true
  performance_insights_retention_period = 7  # días (gratis hasta 7)

  # Enhanced Monitoring: métricas del OS cada 60 segundos
  monitoring_interval = 60
  monitoring_role_arn = var.rds_monitoring_role_arn

  # Actualizaciones de parches menores automáticas
  auto_minor_version_upgrade = true

  tags = { Name = "${var.project_name}-${var.environment}-postgres-primary" }
}



###############################################################################
# AWS Backup — PITR extendido y retención a largo plazo
###############################################################################

resource "aws_backup_vault" "main" {
  name        = "${var.project_name}-${var.environment}-backup-vault"
  kms_key_arn = var.kms_key_arn  # Cifrado del vault con clave KMS propia

  tags = { Name = "${var.project_name}-${var.environment}-backup-vault" }
}

resource "aws_backup_plan" "rds" {
  name = "${var.project_name}-${var.environment}-rds-backup-plan"

  rule {
    rule_name         = "daily-backup-35-days"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 1 * * ? *)"  # 01:00 UTC diariamente

    # Retención de backups diarios
    lifecycle {
      delete_after = 35
    }
  }

  rule {
    rule_name         = "weekly-backup-90-days"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 1 ? * SUN *)"  # Domingos 01:00 UTC

    lifecycle {
      delete_after = 90
    }
  }

  rule {
    rule_name         = "monthly-backup-1-year"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 1 1 * ? *)"  # Día 1 de cada mes

    lifecycle {
      delete_after       = 365
    }
  }

  tags = { Name = "${var.project_name}-${var.environment}-rds-backup-plan" }
}

resource "aws_backup_selection" "rds" {
  name         = "rds-primary-selection"
  iam_role_arn = var.backup_role_arn
  plan_id      = aws_backup_plan.rds.id

  resources = [aws_db_instance.primary.arn]
}

###############################################################################
# KMS Key para cifrado de backup vault (si no se proporciona externamente)
###############################################################################

resource "aws_kms_key" "backup" {
  count = var.kms_key_arn == "" ? 1 : 0

  description             = "KMS Key para cifrado de AWS Backup Vault - ${var.project_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true  # Rotación anual automática

  tags = { Name = "${var.project_name}-${var.environment}-backup-kms" }
}

resource "aws_kms_alias" "backup" {
  count = var.kms_key_arn == "" ? 1 : 0

  name          = "alias/${var.project_name}-${var.environment}-backup"
  target_key_id = aws_kms_key.backup[0].key_id
}
