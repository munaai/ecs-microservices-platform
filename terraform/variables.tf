#VPC AND Security groups

variable "vpc_cidr_block" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "alb_sg_name" {
  type = string
}

variable "ecs_sg_name" {
  type = string
}

variable "rds_sg_name" {
  type = string
}

variable "redis_sg_name" {
  type = string
}

variable "vpc_endpoint_sg_name" {
  type = string
}

#rds
variable "db_subnet_group_name" {
  type = string
}

variable "db_identifier" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "engine_version" {
  type = string
}

variable "instance_class" {
  type = string
}

variable "allocated_storage" {
  type = number
}

variable "multi_az" {
  type = bool
}

variable "backup_retention_period" {
  type = number
}

variable "deletion_protection" {
  type = bool
}

variable "skip_final_snapshot" {
  type = bool
}

# secrets manager
variable "secrets" {
  description = "Map of application secrets."
  type = map(object({
    name        = string
    description = string
  }))
}

#sqs

variable "queue_name" {
  type = string
}

variable "dlq_name" {
  type = string
}

variable "visibility_timeout_seconds" {
  type = number
}

variable "message_retention_seconds" {
  type = number
}

variable "dlq_message_retention_seconds" {
  type = number
}

variable "receive_wait_time_seconds" {
  type = number
}

variable "max_receive_count" {
  type = number
}

# redis

variable "redis_subnet_group_name" {
  type = string
}

variable "redis_replication_group_id" {
  type = string
}

variable "redis_engine_version" {
  type = string
}

variable "redis_node_type" {
  type = string
}

variable "redis_num_cache_clusters" {
  type = number
}

variable "redis_automatic_failover_enabled" {
  type = bool
}

variable "redis_multi_az_enabled" {
  type = bool
}

# vpc endpoints

variable "aws_region" {
  type = string
}

variable "name_prefix" {
  type = string
}

# alb
variable "alb_name" {
  type = string
}

variable "target_group_name" {
  type = string
}

variable "target_group_port" {
  type = number
}

variable "health_check_path" {
  type = string
}

variable "enable_deletion_protection" {
  type = bool
}

variable "domain_name" {
  type = string
}

# ecs cluster

variable "ecs_cluster_name" {
  type = string
}

variable "container_insights_enabled" {
  type = bool
}

# iam

variable "execution_role_name" {
  type = string
}

variable "api_gateway_task_role_name" {
  type = string
}

variable "order_service_task_role_name" {
  type = string
}

variable "payment_service_task_role_name" {
  type = string
}

variable "shipping_service_task_role_name" {
  type = string
}

variable "worker_task_role_name" {
  type = string
}

# cloudwatch

variable "log_group_names" {
  type = list(string)
}

variable "log_retention_in_days" {
  type = number
}

# ecs service

variable "api_gateway_image" {
  type = string
}

variable "order_service_image" {
  type = string
}

variable "inventory_service_image" {
  type = string
}

variable "payment_service_image" {
  type = string
}

variable "notification_service_image" {
  type = string
}

variable "shipping_service_image" {
  type = string
}

variable "dashboard_api_image" {
  type = string
}

variable "worker_image" {
  type = string
}

variable "scheduler_image" {
  type = string
}
