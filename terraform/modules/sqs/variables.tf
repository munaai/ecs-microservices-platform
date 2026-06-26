variable "queue_name" {
  description = "Name of the main SQS queue."
  type        = string
}

variable "dlq_name" {
  description = "Name of the dead-letter queue."
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "How long a message is hidden after a worker receives it."
  type        = number
}

variable "message_retention_seconds" {
  description = "How long messages are kept in the main queue."
  type        = number
}

variable "dlq_message_retention_seconds" {
  description = "How long failed messages are kept in the dead-letter queue."
  type        = number
}

variable "receive_wait_time_seconds" {
  description = "Long polling wait time for receiving messages."
  type        = number
}

variable "max_receive_count" {
  description = "Number of failed receives before a message is moved to the DLQ."
  type        = number
}

variable "tags" {
  description = "Common tags applied to SQS queues."
  type        = map(string)
  default     = {}
}