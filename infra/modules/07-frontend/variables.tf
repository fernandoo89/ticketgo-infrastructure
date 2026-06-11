###############################################################################
# modules/07-frontend/variables.tf
###############################################################################

variable "project_name" { type = string }
variable "environment"  { type = string }

variable "domain_name" {
  description = "Dominio principal (ej: ticketgo.pe). Dejar vacío si no hay dominio custom."
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ARN del certificado ACM en us-east-1 para CloudFront"
  type        = string
  default     = ""
}
