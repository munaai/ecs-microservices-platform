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