resource "aws_secretsmanager_secret" "database_url" {
  name                    = "ecs-microservices/database-url"
  description             = "Database connection string"
  recovery_window_in_days = 0

  tags = {
    Project     = "ecs-microservices-platform"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Owner       = "Muna Ibrahim"
    Name        = "ecs-microservices/database-url"
  }
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "ecs-microservices/jwt-secret"
  description             = "JWT signing secret used by API Gateway"
  recovery_window_in_days = 0

  tags = {
    Project     = "ecs-microservices-platform"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Owner       = "Muna Ibrahim"
    Name        = "ecs-microservices/jwt-secret"
  }
}