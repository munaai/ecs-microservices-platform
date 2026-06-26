variable "secrets" {
  description = "Map of secrets to create."
  type = map(object({
    name        = string
    description = string
  }))
}

variable "recovery_window_in_days" {
  description = "Number of days before a deleted secret is permanently deleted."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Common tags applied to secrets."
  type        = map(string)
  default     = {}
}