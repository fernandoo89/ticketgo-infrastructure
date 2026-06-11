###############################################################################
# modules/07-frontend/outputs.tf
###############################################################################

output "s3_bucket_name" {
  description = "Nombre del bucket S3 de archivos estáticos"
  value       = aws_s3_bucket.frontend.bucket
}

output "s3_bucket_arn" {
  description = "ARN del bucket S3 frontend"
  value       = aws_s3_bucket.frontend.arn
}

output "cloudfront_distribution_id" {
  description = "ID de la distribución CloudFront (para invalidaciones en CI/CD)"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "Dominio CloudFront asignado (*.cloudfront.net)"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "Zone ID de CloudFront para registros Route53 Alias"
  value       = aws_cloudfront_distribution.frontend.hosted_zone_id
}

output "waf_web_acl_arn" {
  description = "ARN del WAF Web ACL de CloudFront"
  value       = aws_wafv2_web_acl.cloudfront.arn
}
