output "alb_sg_id" {
  description = "Security group ID for the ALB."
  value       = aws_security_group.alb.id
}

output "ecs_sg_id" {
  description = "Security group ID for ECS tasks."
  value       = aws_security_group.ecs.id
}

output "rds_sg_id" {
  description = "Security group ID for RDS PostgreSQL."
  value       = aws_security_group.rds.id
}

output "redis_sg_id" {
  description = "Security group ID for Redis."
  value       = aws_security_group.redis.id
}

output "vpc_endpoint_sg_id" {
  description = "Security group ID for VPC interface endpoints."
  value       = aws_security_group.vpc_endpoints.id
}