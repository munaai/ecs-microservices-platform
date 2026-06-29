terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Security group for ALB

resource "aws_security_group" "alb" {
  name        = var.alb_sg_name
  description = "Security group for the public Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = var.alb_sg_name
  })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id

  description = "Allow HTTP from internet"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id

  description = "Allow HTTPS from internet"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_all_outbound" {
  security_group_id = aws_security_group.alb.id

  description = "Allow outbound traffic from ALB"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

# Security group for ECS

resource "aws_security_group" "ecs" {
  name        = var.ecs_sg_name
  description = "Security group for ECS Fargate tasks"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = var.ecs_sg_name
  })
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = aws_security_group.alb.id

  description = "Allow traffic from ALB to ECS tasks"
  from_port   = 8080
  to_port     = 8086
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs_all_outbound" {
  security_group_id = aws_security_group.ecs.id

  description = "Allow ECS tasks outbound traffic"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

# Security group for RDS

resource "aws_security_group" "rds" {
  name        = var.rds_sg_name
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = var.rds_sg_name
  })
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.ecs.id
  description                  = "Allow PostgreSQL from ECS"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "rds_outbound" {
  security_group_id = aws_security_group.rds.id

  description = "Allow all outbound traffic"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

#Security group for redis

resource "aws_security_group" "redis" {
  name        = var.redis_sg_name
  description = "Security group for Redis"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = var.redis_sg_name
  })
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_ecs" {
  security_group_id            = aws_security_group.redis.id
  referenced_security_group_id = aws_security_group.ecs.id
  description                  = "Allow Redis traffic from ECS"
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "redis_outbound" {
  security_group_id = aws_security_group.redis.id

  description = "Allow all outbound traffic"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

# Security group for VPC endpoints

resource "aws_security_group" "vpc_endpoints" {
  name        = var.vpc_endpoint_sg_name
  description = "Security group for VPC interface endpoints"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = var.vpc_endpoint_sg_name
  })
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_ecs" {
  security_group_id            = aws_security_group.vpc_endpoints.id
  referenced_security_group_id = aws_security_group.ecs.id
  description                  = "Allow HTTPS from ECS to interface endpoints"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}