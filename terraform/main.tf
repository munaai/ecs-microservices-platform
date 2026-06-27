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
  db_password   = var.db_password

  engine_version          = var.engine_version
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot

  tags = var.tags
}

module "secrets" {
  source = "./modules/secrets_manager"

  secrets = var.secrets
  tags    = var.tags
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

  alb_name          = var.alb_name
  target_group_name = var.target_group_name
  target_group_port = var.target_group_port
  health_check_path = var.health_check_path
  certificate_arn   = data.aws_acm_certificate.this.arn

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

module "iam" {
  source = "./modules/iam"

  execution_role_name = var.execution_role_name

  task_roles = {
    api_gateway = {
      name = var.api_gateway_task_role_name

      secret_arns = [
        module.secrets_manager.secret_arns["jwt_secret"]
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