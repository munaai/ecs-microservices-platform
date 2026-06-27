output "execution_role_arn" {
  description = "ARN of the execution role."
  value       = aws_iam_role.execution.arn
}

output "task_role_arns" {
  description = "ARNs of the task roles."

  value = {
    for key, role in aws_iam_role.task :
    key => role.arn
  }
}