output "alb_arn" {
  value = aws_lb.this.arn
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_zone_id" {
  value = aws_lb.this.zone_id
}

output "api_gateway_target_group_arn" {
  value = aws_lb_target_group.api_gateway.arn
}

output "dashboard_api_target_group_arn" {
  value = aws_lb_target_group.dashboard_api.arn
}

output "https_listener_arn" {
  value = aws_lb_listener.https.arn
}