variable "vpc_id" {
  description = "ID of the VPC where security groups will be created."
  type        = string
}

variable "alb_sg_name" {
  description = "Name of the ALB security group."
  type        = string
}

variable "ecs_sg_name" {
  description = "Name of the ECS tasks security group."
  type        = string
}

variable "rds_sg_name" {
  description = "Name of the RDS security group."
  type        = string
}

variable "redis_sg_name" {
  description = "Name of the Redis security group."
  type        = string
}

variable "vpc_endpoint_sg_name" {
  description = "Name of the VPC endpoints security group."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all security groups."
  type        = map(string)
  default     = {}
}