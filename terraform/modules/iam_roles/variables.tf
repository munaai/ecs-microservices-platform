variable "execution_role_name" {
  description = "Name of the ECS execution role."
  type        = string
}

variable "task_roles" {
  description = "Task roles to create for ECS services."

  type = map(object({
    name           = string
    secret_arns    = list(string)
    sqs_queue_arns = list(string)
  }))
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}