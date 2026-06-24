variable "vpc_cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "tags" {
  description = "Common tags for all VPC resources."
  type        = map(string)
  default     = {}
}