output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [
    for name, subnet in aws_subnet.this :
    subnet.id
    if local.subnets[name].tier == "public"
  ]
}

output "app_subnet_ids" {
  value = [
    for name, subnet in aws_subnet.this :
    subnet.id
    if local.subnets[name].tier == "app"
  ]
}

output "db_subnet_ids" {
  value = [
    for name, subnet in aws_subnet.this :
    subnet.id
    if local.subnets[name].tier == "db"
  ]
}

output "app_private_route_table_id" {
  value = aws_route_table.app_private.id
}

output "db_private_route_table_id" {
  value = aws_route_table.db_private.id
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}