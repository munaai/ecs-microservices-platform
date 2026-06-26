output "secret_arns" {
  description = "ARNs of created secrets."
  value = {
    for key, secret in aws_secretsmanager_secret.this :
    key => secret.arn
  }
}
