output "service_arns" {
  description = "Cloud Map service ARNs by service name"

  value = {
    for service_name, service in aws_service_discovery_service.this :
    service_name => service.arn
  }
}

output "namespace_name" {
  value = aws_service_discovery_private_dns_namespace.this.name
}