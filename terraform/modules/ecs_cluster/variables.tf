variable "cluster_name" {
  description = "Name of the ECS cluster."
  type        = string
}

variable "tags" {
  description = "Common tags applied to ECS cluster resources."
  type        = map(string)
  default     = {}
}

variable "container_insights_enabled" {
  type    = bool
  default = false
}