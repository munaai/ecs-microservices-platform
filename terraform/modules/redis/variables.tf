variable "redis_subnet_group_name" {
  type = string
}

variable "redis_subnet_ids" {
  type = list(string)
}

variable "redis_sg_id" {
  type = string
}

variable "replication_group_id" {
  type = string
}

variable "engine_version" {
  type = string
}

variable "node_type" {
  type = string
}

variable "num_cache_clusters" {
  type = number
}

variable "automatic_failover_enabled" {
  type = bool
}

variable "multi_az_enabled" {
  type = bool
}

variable "tags" {
  type    = map(string)
  default = {}
}