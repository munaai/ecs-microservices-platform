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