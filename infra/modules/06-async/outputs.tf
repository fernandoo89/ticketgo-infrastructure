###############################################################################
# modules/06-async/outputs.tf
###############################################################################

output "sqs_queue_url" {
  description = "URL de la cola SQS principal de tickets"
  value       = aws_sqs_queue.tickets.url
}

output "sqs_queue_arn" {
  description = "ARN de la cola SQS principal"
  value       = aws_sqs_queue.tickets.arn
}

output "sqs_dlq_arn" {
  description = "ARN de la Dead Letter Queue"
  value       = aws_sqs_queue.tickets_dlq.arn
}

output "lambda_function_name" {
  description = "Nombre de la función Lambda worker"
  value       = aws_lambda_function.ticket_worker.function_name
}

output "lambda_function_arn" {
  description = "ARN de la función Lambda worker"
  value       = aws_lambda_function.ticket_worker.arn
}

output "dlq_alerts_topic_arn" {
  description = "ARN del SNS Topic para alertas de DLQ"
  value       = aws_sns_topic.dlq_alerts.arn
}
