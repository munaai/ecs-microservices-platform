variable "namespace_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "services" {
  type = set(string)
}