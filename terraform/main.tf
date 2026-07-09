module "vpc" {
  source = "./modules/vpc"

  vpc_cidr_block = var.vpc_cidr_block
  tags           = var.tags
}

module "security_groups" {
  source = "./modules/security_groups"

  vpc_id = module.vpc.vpc_id

  alb_sg_name          = var.alb_sg_name
  ecs_sg_name          = var.ecs_sg_name
  rds_sg_name          = var.rds_sg_name
  redis_sg_name        = var.redis_sg_name
  vpc_endpoint_sg_name = var.vpc_endpoint_sg_name

  tags = var.tags
}

module "rds" {
  source = "./modules/rds"

  db_subnet_group_name = var.db_subnet_group_name
  db_subnet_ids        = module.vpc.db_subnet_ids
  rds_sg_id            = module.security_groups.rds_sg_id

  db_identifier = var.db_identifier
  db_name       = var.db_name
  db_username   = var.db_username

  engine_version          = var.engine_version
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot

  tags = var.tags
}

# secrets
data "aws_secretsmanager_secret" "database_url" {
  name = "ecs-microservices/database-url"
}

data "aws_secretsmanager_secret" "jwt_secret" {
  name = "ecs-microservices/jwt-secret"
}

module "sqs" {
  source = "./modules/sqs"

  queue_name                    = var.queue_name
  dlq_name                      = var.dlq_name
  visibility_timeout_seconds    = var.visibility_timeout_seconds
  message_retention_seconds     = var.message_retention_seconds
  dlq_message_retention_seconds = var.dlq_message_retention_seconds
  receive_wait_time_seconds     = var.receive_wait_time_seconds
  max_receive_count             = var.max_receive_count

  tags = var.tags
}

module "redis" {
  source = "./modules/redis"

  redis_subnet_group_name = var.redis_subnet_group_name
  redis_subnet_ids        = module.vpc.db_subnet_ids
  redis_sg_id             = module.security_groups.redis_sg_id

  replication_group_id       = var.redis_replication_group_id
  engine_version             = var.redis_engine_version
  node_type                  = var.redis_node_type
  num_cache_clusters         = var.redis_num_cache_clusters
  automatic_failover_enabled = var.redis_automatic_failover_enabled
  multi_az_enabled           = var.redis_multi_az_enabled

  tags = var.tags
}

module "vpc_endpoints" {
  source = "./modules/vpc_endpoints"

  aws_region         = var.aws_region
  name_prefix        = var.name_prefix
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.app_subnet_ids

  private_route_table_ids = [
    module.vpc.app_private_route_table_id
  ]

  vpc_endpoint_sg_id = module.security_groups.vpc_endpoint_sg_id

  tags = var.tags
}

module "alb" {
  source = "./modules/alb"

  alb_name                        = var.alb_name
  api_gateway_target_group_name   = var.api_gateway_target_group_name
  dashboard_api_target_group_name = var.dashboard_api_target_group_name
  api_gateway_target_group_port   = var.api_gateway_target_group_port
  dashboard_api_target_group_port = var.dashboard_api_target_group_port
  health_check_path               = var.health_check_path
  certificate_arn                 = data.aws_acm_certificate.this.arn

  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_sg_id

  enable_deletion_protection = var.enable_deletion_protection

  tags = var.tags
}

data "aws_acm_certificate" "this" {
  domain      = var.domain_name
  statuses    = ["ISSUED"]
  most_recent = true
}

module "ecs_cluster" {
  source = "./modules/ecs_cluster"

  cluster_name               = var.ecs_cluster_name
  container_insights_enabled = var.container_insights_enabled

  tags = var.tags
}

module "iam_roles" {
  source = "./modules/iam_roles"

  execution_role_name = var.execution_role_name

  execution_secret_arns = [
    data.aws_secretsmanager_secret.database_url.arn,
    data.aws_secretsmanager_secret.jwt_secret.arn
  ]

  task_roles = {
    api_gateway = {
      name = var.api_gateway_task_role_name

      secret_arns = [
        data.aws_secretsmanager_secret.jwt_secret.arn
      ]

      sqs_queue_arns = []
    }

    order_service = {
      name        = var.order_service_task_role_name
      secret_arns = []

      sqs_queue_arns = [
        module.sqs.queue_arn
      ]
    }

    payment_service = {
      name        = var.payment_service_task_role_name
      secret_arns = []

      sqs_queue_arns = [
        module.sqs.queue_arn
      ]
    }

    shipping_service = {
      name        = var.shipping_service_task_role_name
      secret_arns = []

      sqs_queue_arns = [
        module.sqs.queue_arn
      ]
    }

    worker = {
      name        = var.worker_task_role_name
      secret_arns = []

      sqs_queue_arns = [
        module.sqs.queue_arn
      ]
    }
  }

  tags = var.tags
}

module "cloudwatch" {
  source = "./modules/cloudwatch"

  log_group_names   = var.log_group_names
  retention_in_days = var.log_retention_in_days

  tags = var.tags
}

module "api_gateway_service" {
  source = "./modules/ecs_service"

  service_name    = "api-gateway"
  container_name  = "api-gateway"
  container_image = var.api_gateway_image
  container_port  = 8080

  cpu           = 256
  memory        = 512
  desired_count = var.ecs_desired_count

  cluster_arn        = module.ecs_cluster.cluster_arn
  execution_role_arn = module.iam_roles.execution_role_arn
  task_role_arn      = module.iam_roles.task_role_arns["api_gateway"]

  subnet_ids            = module.vpc.app_subnet_ids
  ecs_security_group_id = module.security_groups.ecs_sg_id
  target_group_arn      = module.alb.api_gateway_target_group_arn

  log_group_name = module.cloudwatch.log_group_names["/ecs/api-gateway"]
  aws_region     = var.aws_region

  environment_variables = {
    REDIS_URL  = "redis://${module.redis.primary_endpoint_address}:6379"
    AWS_REGION = var.aws_region

    ORDER_SERVICE_URL        = "http://order-service.internal:8081"
    INVENTORY_SERVICE_URL    = "http://inventory-service.internal:8082"
    PAYMENT_SERVICE_URL      = "http://payment-service.internal:8083"
    NOTIFICATION_SERVICE_URL = "http://notification-service.internal:8084"
    SHIPPING_SERVICE_URL     = "http://shipping-service.internal:8085"
    DASHBOARD_SERVICE_URL    = "http://dashboard-api.internal:8086"
  }

  secrets = {
    JWT_SECRET = data.aws_secretsmanager_secret.jwt_secret.arn
  }

  tags = var.tags
}

module "order_service" {
  source = "./modules/ecs_service"

  service_discovery_arn = module.service_discovery.service_arns["order-service"]

  service_name    = "order-service"
  container_name  = "order-service"
  container_image = var.order_service_image
  container_port  = 8081

  cpu           = 256
  memory        = 512
  desired_count = var.ecs_desired_count

  cluster_arn        = module.ecs_cluster.cluster_arn
  execution_role_arn = module.iam_roles.execution_role_arn
  task_role_arn      = module.iam_roles.task_role_arns["order_service"]

  subnet_ids            = module.vpc.app_subnet_ids
  ecs_security_group_id = module.security_groups.ecs_sg_id
  target_group_arn      = null

  log_group_name = module.cloudwatch.log_group_names["/ecs/order-service"]
  aws_region     = var.aws_region

  environment_variables = {
    SQS_QUEUE_URL = module.sqs.queue_url
    AWS_REGION    = var.aws_region
  }

  secrets = {
    DATABASE_URL = data.aws_secretsmanager_secret.database_url.arn
  }

  tags = var.tags
}

module "inventory_service" {
  source = "./modules/ecs_service"

  service_discovery_arn = module.service_discovery.service_arns["inventory-service"]

  service_name    = "inventory-service"
  container_name  = "inventory-service"
  container_image = var.inventory_service_image
  container_port  = 8082

  cpu           = 256
  memory        = 512
  desired_count = var.ecs_desired_count

  cluster_arn        = module.ecs_cluster.cluster_arn
  execution_role_arn = module.iam_roles.execution_role_arn
  task_role_arn      = null

  subnet_ids            = module.vpc.app_subnet_ids
  ecs_security_group_id = module.security_groups.ecs_sg_id
  target_group_arn      = null

  log_group_name = module.cloudwatch.log_group_names["/ecs/inventory-service"]
  aws_region     = var.aws_region

  environment_variables = {
    AWS_REGION = var.aws_region
  }

  secrets = {
    DATABASE_URL = data.aws_secretsmanager_secret.database_url.arn
  }

  tags = var.tags
}

module "payment_service" {
  source = "./modules/ecs_service"

  service_discovery_arn = module.service_discovery.service_arns["payment-service"]

  service_name    = "payment-service"
  container_name  = "payment-service"
  container_image = var.payment_service_image
  container_port  = 8083

  cpu           = 256
  memory        = 512
  desired_count = var.ecs_desired_count

  cluster_arn        = module.ecs_cluster.cluster_arn
  execution_role_arn = module.iam_roles.execution_role_arn
  task_role_arn      = module.iam_roles.task_role_arns["payment_service"]

  subnet_ids            = module.vpc.app_subnet_ids
  ecs_security_group_id = module.security_groups.ecs_sg_id
  target_group_arn      = null

  log_group_name = module.cloudwatch.log_group_names["/ecs/payment-service"]
  aws_region     = var.aws_region

  environment_variables = {
    SQS_QUEUE_URL = module.sqs.queue_url
    AWS_REGION    = var.aws_region
  }

  secrets = {
    DATABASE_URL = data.aws_secretsmanager_secret.database_url.arn
  }

  tags = var.tags
}

module "notification_service" {
  source = "./modules/ecs_service"

  service_discovery_arn = module.service_discovery.service_arns["notification-service"]

  service_name    = "notification-service"
  container_name  = "notification-service"
  container_image = var.notification_service_image
  container_port  = 8084

  cpu           = 256
  memory        = 512
  desired_count = var.ecs_desired_count

  cluster_arn        = module.ecs_cluster.cluster_arn
  execution_role_arn = module.iam_roles.execution_role_arn
  task_role_arn      = null

  subnet_ids            = module.vpc.app_subnet_ids
  ecs_security_group_id = module.security_groups.ecs_sg_id
  target_group_arn      = null

  log_group_name = module.cloudwatch.log_group_names["/ecs/notification-service"]
  aws_region     = var.aws_region

  environment_variables = {
    AWS_REGION = var.aws_region
  }

  secrets = {
    DATABASE_URL = data.aws_secretsmanager_secret.database_url.arn
  }

  tags = var.tags
}

module "shipping_service" {
  source = "./modules/ecs_service"

  service_discovery_arn = module.service_discovery.service_arns["shipping-service"]

  service_name    = "shipping-service"
  container_name  = "shipping-service"
  container_image = var.shipping_service_image
  container_port  = 8085

  cpu           = 256
  memory        = 512
  desired_count = var.ecs_desired_count

  cluster_arn        = module.ecs_cluster.cluster_arn
  execution_role_arn = module.iam_roles.execution_role_arn
  task_role_arn      = module.iam_roles.task_role_arns["shipping_service"]

  subnet_ids            = module.vpc.app_subnet_ids
  ecs_security_group_id = module.security_groups.ecs_sg_id
  target_group_arn      = null

  log_group_name = module.cloudwatch.log_group_names["/ecs/shipping-service"]
  aws_region     = var.aws_region

  environment_variables = {
    SQS_QUEUE_URL = module.sqs.queue_url
    AWS_REGION    = var.aws_region
  }

  secrets = {
    DATABASE_URL = data.aws_secretsmanager_secret.database_url.arn
  }

  tags = var.tags
}

module "dashboard_api_service" {
  source = "./modules/ecs_service"

  service_discovery_arn = module.service_discovery.service_arns["dashboard-api"]

  service_name    = "dashboard-api"
  container_name  = "dashboard-api"
  container_image = var.dashboard_api_image
  container_port  = 8086

  cpu           = 256
  memory        = 512
  desired_count = var.ecs_desired_count

  cluster_arn        = module.ecs_cluster.cluster_arn
  execution_role_arn = module.iam_roles.execution_role_arn
  task_role_arn      = null

  subnet_ids            = module.vpc.app_subnet_ids
  ecs_security_group_id = module.security_groups.ecs_sg_id
  target_group_arn      = module.alb.dashboard_api_target_group_arn

  log_group_name = module.cloudwatch.log_group_names["/ecs/dashboard-api"]
  aws_region     = var.aws_region

  environment_variables = {
    AWS_REGION = var.aws_region
  }

  secrets = {
    DATABASE_URL = data.aws_secretsmanager_secret.database_url.arn
  }

  tags = var.tags
}

module "worker_service" {
  source = "./modules/ecs_service"

  service_name    = "worker"
  container_name  = "worker"
  container_image = var.worker_image
  container_port  = 8090

  cpu           = 256
  memory        = 512
  desired_count = var.ecs_desired_count

  cluster_arn        = module.ecs_cluster.cluster_arn
  execution_role_arn = module.iam_roles.execution_role_arn
  task_role_arn      = module.iam_roles.task_role_arns["worker"]

  subnet_ids            = module.vpc.app_subnet_ids
  ecs_security_group_id = module.security_groups.ecs_sg_id
  target_group_arn      = null

  log_group_name = module.cloudwatch.log_group_names["/ecs/worker"]
  aws_region     = var.aws_region

  environment_variables = {
    SQS_QUEUE_URL = module.sqs.queue_url
    AWS_REGION    = var.aws_region
  }

  secrets = {}

  tags = var.tags
}

module "scheduler_service" {
  source = "./modules/ecs_service"

  service_name    = "scheduler"
  container_name  = "scheduler"
  container_image = var.scheduler_image
  container_port  = 8091

  cpu           = 256
  memory        = 512
  desired_count = var.ecs_desired_count

  cluster_arn        = module.ecs_cluster.cluster_arn
  execution_role_arn = module.iam_roles.execution_role_arn
  task_role_arn      = null

  subnet_ids            = module.vpc.app_subnet_ids
  ecs_security_group_id = module.security_groups.ecs_sg_id
  target_group_arn      = null

  log_group_name = module.cloudwatch.log_group_names["/ecs/scheduler"]
  aws_region     = var.aws_region

  environment_variables = {
    AWS_REGION = var.aws_region
  }

  secrets = {
    DATABASE_URL = data.aws_secretsmanager_secret.database_url.arn
  }

  tags = var.tags
}

# route53

data "aws_route53_zone" "this" {
  name         = var.root_domain_name
  private_zone = false
}

module "route53" {
  source = "./modules/route53"

  hosted_zone_id = data.aws_route53_zone.this.zone_id
  record_name    = var.app_domain_name

  alb_dns_name = module.alb.alb_dns_name
  alb_zone_id  = module.alb.alb_zone_id
}

module "service_discovery" {
  source = "./modules/service_discovery"

  namespace_name = var.service_discovery_namespace_name
  vpc_id         = module.vpc.vpc_id
  services       = var.service_discovery_services
}