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