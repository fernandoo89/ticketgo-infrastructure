###############################################################################
# modules/01-networking/main.tf
# Crea: VPC, Subnets (Pública / App / Data), IGW, NAT Gateway, Route Tables
#
# Decisiones de HA:
#  - NAT Gateway en CADA AZ pública: si falla una AZ, el tráfico saliente
#    de la otra AZ no depende de la NAT del AZ afectada.
#  - Subnets distribuidas en 2 AZs mínimo → requisito para RDS Multi-AZ,
#    ALB y ECS con alta disponibilidad.
###############################################################################

# ── VPC ───────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true   # Requerido para que ECS resuelva endpoints
  enable_dns_hostnames = true   # Requerido para RDS y ElastiCache

  tags = { Name = "${var.project_name}-${var.environment}-vpc" }
}

# ── Internet Gateway ──────────────────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-${var.environment}-igw" }
}

# ── Subnets Públicas (ALB + NAT Gateway) ─────────────────────────────────────
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  # Seguridad: NO asignamos IP pública automática; solo el ALB y el NAT GW
  # tienen Elastic IPs. Los demás recursos son privados.
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    Tier = "public"
  }
}

# ── Subnets Privadas de Aplicación (ECS Fargate) ─────────────────────────────
resource "aws_subnet" "private_app" {
  count = length(var.private_app_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-private-app-${count.index + 1}"
    Tier = "private-app"
  }
}

# ── Subnets Privadas de Datos (RDS + ElastiCache) ────────────────────────────
resource "aws_subnet" "private_data" {
  count = length(var.private_data_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_data_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-private-data-${count.index + 1}"
    Tier = "private-data"
  }
}

# ── Elastic IPs para NAT Gateways (una por AZ) ───────────────────────────────
resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"

  tags = { Name = "${var.project_name}-${var.environment}-eip-nat-${count.index + 1}" }

  depends_on = [aws_internet_gateway.main]
}

# ── NAT Gateways (uno por AZ = alta disponibilidad saliente) ─────────────────
# Decisión: NAT GW redundante por AZ evita que la pérdida de una AZ corte
# el acceso saliente de los contenedores ECS en la otra AZ.
resource "aws_nat_gateway" "main" {
  count = length(var.public_subnet_cidrs)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = { Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}" }

  depends_on = [aws_internet_gateway.main]
}

# ── Route Table Pública ───────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project_name}-${var.environment}-rt-public" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Route Tables Privadas de Aplicación (una por AZ → su propio NAT GW) ──────
resource "aws_route_table" "private_app" {
  count  = length(var.private_app_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = { Name = "${var.project_name}-${var.environment}-rt-private-app-${count.index + 1}" }
}

resource "aws_route_table_association" "private_app" {
  count          = length(aws_subnet.private_app)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

# ── Route Tables Privadas de Datos (una por AZ) ───────────────────────────────
resource "aws_route_table" "private_data" {
  count  = length(var.private_data_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = { Name = "${var.project_name}-${var.environment}-rt-private-data-${count.index + 1}" }
}

resource "aws_route_table_association" "private_data" {
  count          = length(aws_subnet.private_data)
  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private_data[count.index].id
}

# ── VPC Flow Logs (Seguridad: auditoría de tráfico de red) ───────────────────
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs/${var.project_name}-${var.environment}-v3"
  retention_in_days = 90  # Retención 90 días para cumplimiento y forensics

  tags = { Name = "${var.project_name}-${var.environment}-vpc-flow-logs" }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.project_name}-${var.environment}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn

  tags = { Name = "${var.project_name}-${var.environment}-flow-log" }
}
# ── Security Group: VPC Endpoints ─────────────────────────────────────────────
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-${var.environment}-sg-vpce"
  description = "Trafico HTTPS desde VPC hacia Interface Endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS desde recursos dentro del VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = { Name = "${var.project_name}-${var.environment}-sg-vpce" }
}

# ── VPC Endpoints (reduce latencia y costos de datos) ────────────────────────
# Decisión: S3 Gateway endpoint → los contenedores acceden a S3 sin pasar
# por NAT Gateway, ahorrando costos de transferencia y mejorando latencia.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    aws_route_table.private_app[*].id,
    aws_route_table.private_data[*].id
  )

  tags = { Name = "${var.project_name}-${var.environment}-vpce-s3" }
}

# ECR API + DKR endpoints → ECS Fargate jala imágenes sin NAT Gateway
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.project_name}-${var.environment}-vpce-ecr-api" }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.project_name}-${var.environment}-vpce-ecr-dkr" }
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.project_name}-${var.environment}-vpce-secretsmanager" }
}

resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.project_name}-${var.environment}-vpce-logs" }
}
