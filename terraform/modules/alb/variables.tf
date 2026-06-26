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

variable "certificate_arn" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "enable_deletion_protection" {
  type = bool
}

variable "tags" {
  type    = map(string)
  default = {}
}