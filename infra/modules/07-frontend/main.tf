###############################################################################
# modules/07-frontend/main.tf
# Crea: S3 bucket privado, CloudFront con OAC, AWS WAF, Route53 (opcional)
#
# Decisiones de seguridad:
#  - OAC (Origin Access Control): sustituto moderno de OAI, CloudFront firma
#    requests con SigV4 — el bucket es 100% privado, sin acceso directo.
#  - WAF con managed rules: protege contra OWASP Top 10, ataques de bots y
#    IPs maliciosas conocidas sin configuración manual de reglas.
#  - HTTPS-only con TLS 1.2 mínimo: fuerza cifrado en tránsito.
#  - CloudFront Functions para headers de seguridad: HSTS, X-Frame-Options, etc.
###############################################################################

# ── S3 Bucket — Archivos Estáticos (React/Vue) ───────────────────────────────
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-${var.environment}-frontend-${data.aws_caller_identity.current.account_id}"

  tags = { Name = "${var.project_name}-${var.environment}-frontend" }
}

data "aws_caller_identity" "current" {}

# Bloquear todo acceso público directo — solo CloudFront puede leer
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versionado: permite rollback de deploys del frontend
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Cifrado en reposo del bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle: eliminar versiones antiguas después de 30 días para ahorrar costos
resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ── CloudFront Origin Access Control (OAC) ───────────────────────────────────
# OAC es el sucesor de OAI — autentica CloudFront ante S3 con SigV4
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-${var.environment}-oac"
  description                       = "OAC para acceso de CloudFront a S3 frontend de TicketGo"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ── CloudFront Function — Security Headers ────────────────────────────────────
# Agrega headers de seguridad HTTP a todas las respuestas (HSTS, CSP, etc.)
resource "aws_cloudfront_function" "security_headers" {
  name    = "${var.project_name}-${var.environment}-security-headers"
  runtime = "cloudfront-js-2.0"
  comment = "Agrega headers de seguridad HTTP a todas las respuestas"
  publish = true

  code = <<-EOF
    async function handler(event) {
      const response = event.response;
      const headers = response.headers;

      // HSTS: fuerza HTTPS por 1 año, incluye subdominios
      headers['strict-transport-security'] = { value: 'max-age=31536000; includeSubdomains; preload' };

      // Previene clickjacking
      headers['x-frame-options'] = { value: 'DENY' };

      // Previene MIME sniffing
      headers['x-content-type-options'] = { value: 'nosniff' };

      // Referrer Policy seguro
      headers['referrer-policy'] = { value: 'strict-origin-when-cross-origin' };

      // Permissions Policy: deshabilita APIs no usadas
      headers['permissions-policy'] = { value: 'camera=(), microphone=(), geolocation=()' };

      // Content Security Policy básico (ajustar según la app)
      headers['content-security-policy'] = {
        value: "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https://*.amazonaws.com"
      };

      return response;
    }
  EOF
}

# ── WAF Web ACL (Provider us-east-1 requerido por CloudFront) ─────────────────
resource "aws_wafv2_web_acl" "cloudfront" {
  provider    = aws.us_east_1
  name        = "${var.project_name}-${var.environment}-waf-cloudfront"
  description = "WAF para CloudFront de TicketGo - proteccion OWASP + bots"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}  # Permitir por defecto; las reglas bloquean lo malicioso
  }

  # Regla 1: AWS Managed Rules — Common Rule Set (OWASP Top 10)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Regla 2: Known Bad Inputs (inyecciones, path traversal)
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Regla 3: Bot Control — protege contra scrapers y bots de compra automatizada
  # CRÍTICO para TicketGo: evita que bots compren todos los tickets en segundos
  rule {
    name     = "AWSManagedRulesBotControlRuleSet"
    priority = 30

    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"

        managed_rule_group_configs {
          aws_managed_rules_bot_control_rule_set {
            inspection_level = "COMMON"
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BotControlRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Regla 4: Rate Limiting — máximo 2000 requests/5min por IP
  # Anti-thundering herd: evita que una IP sola agote la capacidad
  rule {
    name     = "RateLimitRule"
    priority = 40

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-waf-cloudfront"
    sampled_requests_enabled   = true
  }

  tags = { Name = "${var.project_name}-${var.environment}-waf-cloudfront" }
}

# ── CloudFront Distribution ───────────────────────────────────────────────────
resource "aws_cloudfront_distribution" "frontend" {
  comment     = "CDN para frontend TicketGo ${var.environment} - React/Vue"
  enabled     = true
  price_class = "PriceClass_100"  # Solo US, Europe, Asia (cubre Perú vía US East)
  aliases     = var.domain_name != "" ? [var.domain_name, "www.${var.domain_name}"] : []

  # Origen: S3 privado con OAC
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.frontend.bucket}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # Comportamiento por defecto
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.frontend.bucket}"
    viewer_protocol_policy = "redirect-to-https"  # Fuerza HTTPS

    # Cache optimizado para archivos estáticos (1 día de TTL)
    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6"  # CachingOptimized
    origin_request_policy_id   = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcb"  # CORS-S3Origin
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id

    # CloudFront Function para headers adicionales de seguridad
    function_association {
      event_type   = "viewer-response"
      function_arn = aws_cloudfront_function.security_headers.arn
    }
  }

  # Comportamiento para assets con hash (JS/CSS con content hash → caché larga)
  ordered_cache_behavior {
    path_pattern           = "/static/*"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.frontend.bucket}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # Cache agresivo: 1 año (los archivos tienen hash en el nombre)
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"  # CachingDisabled no, usamos custom
    min_ttl         = 31536000
    default_ttl     = 31536000
    max_ttl         = 31536000

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  # SPA: redirigir 403/404 de S3 al index.html (React Router)
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  default_root_object = "index.html"

  # WAF asociado a CloudFront
  web_acl_id = aws_wafv2_web_acl.cloudfront.arn

  # Certificado SSL
  viewer_certificate {
    acm_certificate_arn            = var.acm_certificate_arn != "" ? var.acm_certificate_arn : null
    cloudfront_default_certificate = var.acm_certificate_arn == ""
    ssl_support_method             = var.acm_certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = var.acm_certificate_arn != "" ? "TLSv1.2_2021" : null
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"  # Sin restricciones geográficas (TicketGo es global)
    }
  }

  tags = { Name = "${var.project_name}-${var.environment}-cloudfront" }
}

# ── Response Headers Policy ───────────────────────────────────────────────────
resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "${var.project_name}-${var.environment}-security-headers-policy"
  comment = "Security headers para CloudFront de TicketGo"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }
}

# ── S3 Bucket Policy — Solo CloudFront puede leer (OAC) ───────────────────────
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })
}
