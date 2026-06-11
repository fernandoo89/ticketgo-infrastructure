###############################################################################
# modules/05-compute/variables.tf
###############################################################################

variable "project_name" { type = string }
variable "environment"  { type = string }
variable "aws_region"   { type = string }

variable "vpc_id"               { type = string }
variable "public_subnet_ids"    { type = list(string) }
variable "private_app_subnet_ids" { type = list(string) }

variable "sg_alb_id"  { type = string }
variable "sg_ecs_id"  { type = string }

variable "container_image"  { type = string }
variable "container_port"   { type = number; default = 8080 }
variable "container_cpu"    { type = number; default = 1024 }
variable "container_memory" { type = number; default = 2048 }

variable "ecs_desired_count"  { type = number; default = 3  }
variable "ecs_min_capacity"   { type = number; default = 2  }
variable "ecs_max_capacity"   { type = number; default = 20 }

variable "ecs_task_execution_role_arn" { type = string }
variable "ecs_task_role_arn"           { type = string }

variable "db_secret_arn"            { type = string }
variable "db_read_replica_endpoint" { type = string }
variable "redis_primary_endpoint"   { type = string }

variable "acm_certificate_arn" { type = string }
