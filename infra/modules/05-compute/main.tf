###############################################################################
# modules/05-compute/main.tf
# Crea: ECR, ALB (HTTPS), ECS Cluster + Service + Task Definition, Auto Scaling
#
# Decisiones de HA y Anti-thundering herd:
#  - ALB con múltiples targets en 2 AZs: el tráfico se distribuye entre
#    contenedores en ambas AZs.
#  - Auto Scaling basado en CPU Y Memoria: ante picos de venta de tickets,
#    ECS escala horizontalmente antes de saturarse.
#  - ECS Fargate: sin gestión de instancias EC2; AWS gestiona la infraestructura
#    subyacente y la distribución de tareas.
#  - Listener con redirect HTTP→HTTPS: fuerza HTTPS en todos los clientes.
###############################################################################

# ── ECR Repository ────────────────────────────────────────────────────────────
resource "aws_ecr_repository" "api" {
  name                 = "${var.project_name}-${var.environment}-api"
  image_tag_mutability = "MUTABLE"  # Permite re-tag de imágenes (latest)

  # Seguridad: escaneo automático de vulnerabilidades en cada push
  image_scanning_configuration {
    scan_on_push = true
  }

  # Cifrado de imágenes en reposo
  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = { Name = "${var.project_name}-${var.environment}-ecr-api" }
}

# Lifecycle Policy: mantener solo las últimas 10 imágenes para controlar costos
resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Mantener las ultimas 10 imagenes tagged"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = ["v", "latest"]
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = { type = "expire" }
    },
    {
      rulePriority = 2
      description  = "Eliminar imagenes sin tag mayores a 7 dias"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 7
      }
      action = { type = "expire" }
    }]
  })
}

# ── CloudWatch Log Group para ECS ─────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}-${var.environment}/api"
  retention_in_days = 30

  tags = { Name = "${var.project_name}-${var.environment}-ecs-logs" }
}

# ── ECS Cluster ───────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  # Container Insights: métricas detalladas de CPU/Memoria por tarea en CloudWatch
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${var.project_name}-${var.environment}-ecs-cluster" }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  # Estrategia: usar FARGATE_SPOT para reducir costos en tareas de bajo riesgo
  default_capacity_provider_strategy {
    base              = var.ecs_desired_count  # Tareas base siempre en FARGATE
    weight            = 1
    capacity_provider = "FARGATE"
  }
}

# ── Task Definition ───────────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-${var.environment}-api"
  network_mode             = "awsvpc"        # Requerido para Fargate
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = var.ecs_task_execution_role_arn  # Pull ECR + leer secrets
  task_role_arn            = var.ecs_task_role_arn            # Permisos de la app (SQS)

  container_definitions = jsonencode([{
    name      = "${var.project_name}-api"
    image     = var.container_image
    essential = true

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    # Variables de entorno NO sensibles
    environment = [
      { name = "ASPNETCORE_ENVIRONMENT", value = "Production" },
      { name = "ASPNETCORE_URLS",        value = "http://+:${var.container_port}" },
      { name = "REDIS_ENDPOINT",         value = var.redis_primary_endpoint }
    ]

    # Variables sensibles inyectadas desde Secrets Manager (nunca en logs)
    secrets = [
      {
        name      = "DB_CONNECTION_STRING"
        valueFrom = "${var.db_secret_arn}:::"
      }
    ]

    # Logging hacia CloudWatch
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }

    # Health check del contenedor (complementa el del ALB)
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
      interval    = 30
      timeout     = 10
      retries     = 3
      startPeriod = 60  # Tiempo de arranque para ASP.NET Core
    }
  }])

  tags = { Name = "${var.project_name}-${var.environment}-task-def" }
}

# ── Application Load Balancer ─────────────────────────────────────────────────
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb-v2"
  internal           = false          # Público: accesible desde Internet
  load_balancer_type = "application"
  security_groups    = [var.sg_alb_id]
  subnets            = var.public_subnet_ids

  # Protección contra borrado accidental
  enable_deletion_protection = false

  # Access logs para auditoría y diagnóstico
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb-logs"
    enabled = true
  }

  tags = { Name = "${var.project_name}-${var.environment}-alb" }
}

# Bucket S3 para logs del ALB
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.project_name}-${var.environment}-alb-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = { Name = "${var.project_name}-${var.environment}-alb-logs" }
}

# Cifrado en reposo para el bucket de logs
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versionado para el bucket de logs
resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter { prefix = "alb-logs/" }

    expiration { days = 90 }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Política para que el ALB pueda escribir en S3
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_elb_service_account.main.id}:root" }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.alb_logs.arn}/alb-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    }]
  })
}

data "aws_caller_identity" "current" {}
data "aws_elb_service_account" "main" {}

# Target Group del ALB
resource "aws_lb_target_group" "api" {
  name        = "${var.project_name}-${var.environment}-tg-api"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"    # Fargate usa IPs de ENI, no instancias
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    matcher             = "200"
  }

  # Deregistration delay reducido: más rápido el scale-in sin requests pendientes
  deregistration_delay = 30

  tags = { Name = "${var.project_name}-${var.environment}-tg-api" }
}

# Listener HTTP (80) — Tráfico directo para modo pruebas sin dominio
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# ── ECS Service ───────────────────────────────────────────────────────────────
resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-${var.environment}-api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"
  
  depends_on = [aws_lb_listener.http]

  # Permite actualizaciones del Task Definition sin downtime (rolling update)
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Estrategia de despliegue tipo Blue/Green compatible con CodeDeploy
  deployment_controller {
    type = "ECS"
  }

  # Circuit breaker: si el despliegue falla, revierte automáticamente
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.sg_ecs_id]
    assign_public_ip = false  # Seguridad: las tareas Fargate no tienen IP pública
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "${var.project_name}-api"
    container_port   = var.container_port
  }

  # Spread entre AZs para alta disponibilidad


  lifecycle {
    ignore_changes = [desired_count]  # El auto scaling maneja el conteo en runtime
  }

  tags = { Name = "${var.project_name}-${var.environment}-ecs-service" }
}

# ── Auto Scaling ──────────────────────────────────────────────────────────────
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.ecs_max_capacity   # Hasta 20 tareas en picos
  min_capacity       = var.ecs_min_capacity   # Mínimo 2 para HA
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scale Out por CPU > 70%: escala antes de saturar la CPU
resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.project_name}-${var.environment}-ecs-scale-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    scale_in_cooldown  = 300   # 5 minutos de cooldown para scale-in
    scale_out_cooldown = 60    # 60s para escalar rápido ante picos de tickets

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# Scale Out por Memoria > 75%
resource "aws_appautoscaling_policy" "memory" {
  name               = "${var.project_name}-${var.environment}-ecs-scale-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 75.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}

# Scale Out por ALB Request Count (anti-thundering herd)
# Cuando hay una avalancha de compras, el conteo de requests dispara el escalado
# antes de que la CPU o memoria se saturen.
resource "aws_appautoscaling_policy" "alb_requests" {
  name               = "${var.project_name}-${var.environment}-ecs-scale-requests"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 1000   # 1000 requests/minuto por tarea antes de escalar
    scale_in_cooldown  = 300
    scale_out_cooldown = 30     # Escala muy rápido ante picos de venta

    customized_metric_specification {
      metric_name = "RequestCountPerTarget"
      namespace   = "AWS/ApplicationELB"
      statistic   = "Sum"
      unit        = "Count"

      dimensions {
        name  = "TargetGroup"
        value = aws_lb_target_group.api.arn_suffix
      }
    }
  }
}

# ── CloudWatch Alarmas ────────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Mas de 10 errores 5xx en el ALB en 2 minutos"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
}
