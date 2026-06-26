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

variable "secrets" {
  description = "Map of application secrets."
  type = map(object({
    name          = string
    description   = string
  }))
}