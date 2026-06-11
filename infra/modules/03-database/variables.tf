###############################################################################
# modules/03-database/variables.tf
###############################################################################

variable "project_name" { type = string }
variable "environment"  { type = string }

variable "private_data_subnet_ids" {
  description = "IDs de las subredes privadas de datos para RDS"
  type        = list(string)
}

variable "sg_rds_id" {
  description = "ID del Security Group de RDS"
  type        = string
}

variable "db_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "db_name" { type = string }
variable "db_username" {
  type      = string
  sensitive = true
}
variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_allocated_storage" {
  type    = number
  default = 100
}

variable "db_max_allocated_storage" {
  type    = number
  default = 500
}

variable "rds_monitoring_role_arn" {
  description = "ARN del role para Enhanced Monitoring de RDS"
  type        = string
  default     = ""
}

variable "backup_role_arn" {
  description = "ARN del IAM Role de AWS Backup"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN de KMS Key para cifrar el vault. Si vacío, se crea uno nuevo."
  type        = string
  default     = ""
}
