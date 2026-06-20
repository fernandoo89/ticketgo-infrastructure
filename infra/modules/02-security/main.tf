###############################################################################
# modules/02-security/main.tf
# Crea: Security Groups, IAM Roles (ECS, Lambda, Backup), Secrets Manager
#
# Principio de mínimo privilegio:
#  - RDS solo acepta tráfico del SG de ECS en el puerto 5432.
#  - Redis solo acepta tráfico del SG de ECS en el puerto 6379.
#  - ECS solo acepta tráfico del SG del ALB en el puerto del contenedor.
#  - ALB acepta tráfico público en 443/80.
###############################################################################

# ── Security Group: ALB Público ───────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-sg-alb"
  description = "Trafico publico HTTPS/HTTP hacia el Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS desde Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP desde Internet (redirect a HTTPS en el listener)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Todo el trafico saliente al VPC (hacia ECS)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${var.project_name}-${var.environment}-sg-alb" }
}

# ── Security Group: ECS Fargate ───────────────────────────────────────────────
# Seguridad: Solo acepta tráfico del ALB, no expone puertos directamente a Internet
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-${var.environment}-sg-ecs"
  description = "Trafico hacia contenedores ECS Fargate - solo desde el ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Puerto de la app desde el ALB unicamente"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Salida total para acceso a AWS APIs, RDS, Redis, SQS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-sg-ecs" }
}

# ── Security Group: RDS PostgreSQL ────────────────────────────────────────────
# Seguridad: RDS SOLO acepta conexiones del SG de ECS (zero-trust networking)
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-sg-rds"
  description = "Acceso a RDS PostgreSQL exclusivamente desde ECS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL desde ECS Fargate unicamente"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  # Sin egress explícito → AWS aplica la regla de denegación por defecto
  tags = { Name = "${var.project_name}-${var.environment}-sg-rds" }
}

# ── Security Group: ElastiCache Redis ─────────────────────────────────────────
# Seguridad: Redis SOLO acepta conexiones del SG de ECS
resource "aws_security_group" "redis" {
  name        = "${var.project_name}-${var.environment}-sg-redis"
  description = "Acceso a ElastiCache Redis exclusivamente desde ECS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis desde ECS Fargate unicamente"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = { Name = "${var.project_name}-${var.environment}-sg-redis" }
}

# ── Security Group: Lambda Worker ─────────────────────────────────────────────
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-sg-lambda"
  description = "Security Group para Lambda worker de procesamiento SQS"
  vpc_id      = var.vpc_id

  egress {
    description = "Salida total para acceder a SQS, RDS y otros servicios"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-sg-lambda" }
}


###############################################################################
# IAM — Roles de Ejecución
###############################################################################

# ── IAM Role: ECS Task Execution (para pull de imágenes ECR y logs) ───────────
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-${var.environment}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = { Name = "${var.project_name}-${var.environment}-ecs-execution-role" }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Permiso adicional para leer secretos de Secrets Manager durante el arranque
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "ecs-read-secrets"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "kms:Decrypt"
      ]
      Resource = [
        "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.project_name}/${var.environment}/*"
      ]
    }]
  })
}

# ── IAM Role: ECS Task (permisos de la aplicación en runtime) ─────────────────
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = { Name = "${var.project_name}-${var.environment}-ecs-task-role" }
}

resource "aws_iam_role_policy" "ecs_task_app" {
  name = "ecs-task-app-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Permisos para enviar mensajes a SQS (publicar tickets)
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = "arn:aws:sqs:${var.aws_region}:*:${var.project_name}-${var.environment}-*"
      },
      {
        # Permisos para CloudWatch metrics personalizadas
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
      }
    ]
  })
}

# ── IAM Role: Lambda SQS Worker ───────────────────────────────────────────────
resource "aws_iam_role" "lambda_worker" {
  name = "${var.project_name}-${var.environment}-lambda-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = { Name = "${var.project_name}-${var.environment}-lambda-worker-role" }
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_worker.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_worker_policy" {
  name = "lambda-worker-policy"
  role = aws_iam_role.lambda_worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = "arn:aws:sqs:${var.aws_region}:*:${var.project_name}-${var.environment}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.project_name}/${var.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

# ── IAM Role: AWS Backup ───────────────────────────────────────────────────────
resource "aws_iam_role" "backup" {
  name = "${var.project_name}-${var.environment}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup_managed" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

###############################################################################
# Secrets Manager — Gestión de credenciales sin hardcoding
###############################################################################

# Genera una contraseña aleatoria y segura para RDS (nunca se hardcodea)
resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>?"
}

# Secret principal: credenciales de base de datos
# Los contenedores ECS inyectan este secreto como variables de entorno en el
# Task Definition, evitando que aparezcan en logs o código fuente.
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}/${var.environment}/db-credentials-v2"
  description             = "Credenciales de la base de datos RDS PostgreSQL"
  recovery_window_in_days = 30  # Protección contra borrado accidental

  tags = { Name = "${var.project_name}-${var.environment}-db-secret" }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = var.db_endpoint   # Disponible solo después de crear RDS
    port     = 5432
    dbname   = var.db_name
  })

  # Nota: el host de RDS se actualiza post-creación vía depends_on en el módulo principal
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Secret para la URL de conexión Redis
resource "aws_secretsmanager_secret" "redis_url" {
  name                    = "${var.project_name}/${var.environment}/redis-url-v2"
  description             = "URL de conexion a ElastiCache Redis"
  recovery_window_in_days = 30

  tags = { Name = "${var.project_name}-${var.environment}-redis-secret" }
}
