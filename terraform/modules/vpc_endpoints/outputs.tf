output "interface_endpoint_ids" {
  value = {
    for key, endpoint in aws_vpc_endpoint.interface :
    key => endpoint.id
  }
}

output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}