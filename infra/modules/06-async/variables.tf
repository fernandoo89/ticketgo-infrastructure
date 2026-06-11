###############################################################################
# modules/06-async/variables.tf
###############################################################################

variable "project_name" { type = string }
variable "environment"  { type = string }

variable "private_app_subnet_ids" { type = list(string) }
variable "sg_lambda_id"           { type = string }

variable "lambda_worker_role_arn" { type = string }
variable "lambda_runtime" {
  type    = string
  default = "nodejs20.x"
}

variable "db_secret_arn" { type = string }

variable "sqs_visibility_timeout" {
  description = "Visibility timeout de SQS en segundos (debe ser >= 6x timeout Lambda)"
  type        = number
  default     = 300
}
