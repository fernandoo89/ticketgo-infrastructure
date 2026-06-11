###############################################################################
# modules/04-cache/variables.tf
###############################################################################

variable "project_name" { type = string }
variable "environment"  { type = string }

variable "private_data_subnet_ids" {
  description = "IDs de las subredes privadas de datos para ElastiCache"
  type        = list(string)
}

variable "sg_redis_id" {
  description = "ID del Security Group de Redis"
  type        = string
}

variable "redis_node_type" {
  type    = string
  default = "cache.r6g.large"
}

variable "redis_num_cache_nodes" {
  description = "Número total de nodos (1 primario + N réplicas)"
  type        = number
  default     = 2
}
