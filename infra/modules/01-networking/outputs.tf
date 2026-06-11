###############################################################################
# modules/01-networking/outputs.tf
###############################################################################

output "vpc_id" {
  description = "ID de la VPC principal"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block de la VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas (ALB, NAT)"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "IDs de las subredes privadas de aplicación (ECS Fargate)"
  value       = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  description = "IDs de las subredes privadas de datos (RDS, Redis)"
  value       = aws_subnet.private_data[*].id
}

output "nat_gateway_ids" {
  description = "IDs de los NAT Gateways (uno por AZ)"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "IPs públicas de los NAT Gateways (para whitelisting externo)"
  value       = aws_eip.nat[*].public_ip
}

output "internet_gateway_id" {
  description = "ID del Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "availability_zones" {
  description = "Lista de AZs usadas"
  value       = var.availability_zones
}
