###############################################################################
# modules/06-async/main.tf
# Crea: SQS Queue (con DLQ), Lambda Worker, Event Source Mapping
#
# Decisiones de resiliencia:
#  - Dead Letter Queue (DLQ): mensajes que fallan N veces van a la DLQ para
#    análisis y reprocesamiento manual, sin perder datos.
#  - Visibility Timeout en SQS = 6x el timeout de Lambda: evita que el mismo
#    mensaje sea procesado por múltiples Lambda simultáneamente.
#  - Lambda Destination para fallos: envía notificaciones a SNS cuando una
#    invocación async falla (para alertas operacionales).
#  - SQS con cifrado KMS: los mensajes de compra de tickets son sensibles.
###############################################################################

# ── SQS — Dead Letter Queue ───────────────────────────────────────────────────
resource "aws_sqs_queue" "tickets_dlq" {
  name                      = "${var.project_name}-${var.environment}-tickets-dlq"
  message_retention_seconds = 1209600  # 14 días para análisis post-fallo

  kms_master_key_id = "alias/aws/sqs"  # Cifrado SSE-SQS por defecto

  tags = { Name = "${var.project_name}-${var.environment}-tickets-dlq" }
}

# ── SQS — Cola Principal de Tickets ───────────────────────────────────────────
resource "aws_sqs_queue" "tickets" {
  name                       = "${var.project_name}-${var.environment}-tickets"
  visibility_timeout_seconds = var.sqs_visibility_timeout  # Debe ser >= 6x el timeout Lambda

  # Retención: 4 días (tiempo suficiente para que Lambda procese en degraded mode)
  message_retention_seconds = 345600

  # Delay de entrega: 0s (procesamiento inmediato)
  delay_seconds = 0

  # Long Polling: reduce costos de polling vacío (20s máximo)
  receive_wait_time_seconds = 20

  # Cifrado de mensajes en tránsito y en reposo
  kms_master_key_id                 = "alias/aws/sqs"
  kms_data_key_reuse_period_seconds = 300

  # Configurar DLQ: después de 3 intentos fallidos, el mensaje va a la DLQ
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.tickets_dlq.arn
    maxReceiveCount     = 3
  })

  tags = { Name = "${var.project_name}-${var.environment}-tickets-queue" }
}

# ── SNS Topic para alertas de DLQ ─────────────────────────────────────────────
resource "aws_sns_topic" "dlq_alerts" {
  name = "${var.project_name}-${var.environment}-dlq-alerts"
  tags = { Name = "${var.project_name}-${var.environment}-dlq-alerts" }
}

# Alarma: si hay mensajes en la DLQ, notificar al equipo de operaciones
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.project_name}-${var.environment}-dlq-not-empty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Hay mensajes en la DLQ de tickets - revisar errores"
  alarm_actions       = [aws_sns_topic.dlq_alerts.arn]

  dimensions = {
    QueueName = aws_sqs_queue.tickets_dlq.name
  }
}

# ── CloudWatch Log Group para Lambda ─────────────────────────────────────────
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-ticket-worker"
  retention_in_days = 30

  tags = { Name = "${var.project_name}-${var.environment}-lambda-logs" }
}

# ── Lambda Function — Worker de Tickets ───────────────────────────────────────
resource "aws_lambda_function" "ticket_worker" {
  function_name = "${var.project_name}-${var.environment}-ticket-worker"
  description   = "Procesa mensajes SQS de compra de tickets de forma asincrona"

  # Código: el ZIP se sube desde el pipeline CI/CD (apps/worker-async/)
  # Para el primer despliegue, se usa un placeholder. El CI/CD lo actualiza.
  filename         = "${path.module}/placeholder.zip"
  source_code_hash = filebase64sha256("${path.module}/placeholder.zip")
  handler          = "index.handler"
  runtime          = var.lambda_runtime

  # Timeout conservador: el procesamiento de un ticket incluye DB writes
  timeout     = 60    # segundos
  memory_size = 512   # MB

  role = var.lambda_worker_role_arn

  # VPC: Lambda dentro del VPC para acceder a RDS directamente si es necesario
  vpc_config {
    subnet_ids         = var.private_app_subnet_ids
    security_group_ids = [var.sg_lambda_id]
  }

  # Variables de entorno no sensibles
  environment {
    variables = {
      ENVIRONMENT    = var.environment
      SQS_QUEUE_URL  = aws_sqs_queue.tickets.url
      DB_SECRET_ARN  = var.db_secret_arn
    }
  }

  # Reserva de concurrencia: limita el impact en picos extremos (anti-thundering-herd)
  # 50 invocaciones simultáneas es suficiente para procesar la cola sin sobrecargar RDS
  reserved_concurrent_executions = 50

  # X-Ray tracing para observabilidad distribuida
  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = { Name = "${var.project_name}-${var.environment}-ticket-worker" }

  lifecycle {
    ignore_changes = [filename, source_code_hash]  # CI/CD actualiza el código
  }
}

# ── Event Source Mapping SQS → Lambda ─────────────────────────────────────────
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.tickets.arn
  function_name    = aws_lambda_function.ticket_worker.arn

  # Batch de 10 mensajes por invocación: procesa en lote para eficiencia
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5

  # Report batch item failures: permite que Lambda reporte mensajes fallidos
  # individualmente, sin reintentar los que ya procesó exitosamente.
  function_response_types = ["ReportBatchItemFailures"]

  # Filtro de mensajes: procesar solo mensajes con tipo "ticket_purchase"
  filter_criteria {
    filter {
      pattern = jsonencode({ body = { type = ["ticket_purchase"] } })
    }
  }
}

# ── Placeholder ZIP para primer despliegue ────────────────────────────────────
# Este recurso crea un ZIP mínimo para que Terraform pueda crear la función
# sin que el CI/CD haya subido el código real aún.
resource "local_file" "lambda_placeholder" {
  content  = <<-EOF
    exports.handler = async (event) => {
      console.log('Placeholder Lambda - Deploy via CI/CD pipeline');
      return { statusCode: 200 };
    };
  EOF
  filename = "${path.module}/index.js"
}

data "archive_file" "lambda_placeholder" {
  type        = "zip"
  source_file = local_file.lambda_placeholder.filename
  output_path = "${path.module}/placeholder.zip"
}
