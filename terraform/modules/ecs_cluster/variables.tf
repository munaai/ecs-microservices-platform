variable "cluster_name" {
  description = "Name of the ECS cluster."
  type        = string
}

variable "container_insights_enabled" {
  description = "Whether to enable CloudWatch Container Insights."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags applied to ECS cluster resources."
  type        = map(string)
  default     = {}
}