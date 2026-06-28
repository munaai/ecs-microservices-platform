output "log_group_names" {
  description = "Created CloudWatch log group names."

  value = {
    for key, log_group in aws_cloudwatch_log_group.this :
    key => log_group.name
  }
}

output "log_group_arns" {
  description = "Created CloudWatch log group ARNs."

  value = {
    for key, log_group in aws_cloudwatch_log_group.this :
    key => log_group.arn
  }
}