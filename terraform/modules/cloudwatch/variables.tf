variable "log_group_names" {
  description = "List of CloudWatch log group names to create."
  type        = list(string)
}

variable "retention_in_days" {
  description = "Number of days to retain logs."
  type        = number
}

variable "tags" {
  description = "Common tags applied to log groups."
  type        = map(string)
  default     = {}
}