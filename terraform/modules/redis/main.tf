resource "aws_elasticache_subnet_group" "this" {
  name       = var.redis_subnet_group_name
  subnet_ids = var.redis_subnet_ids

  tags = merge(var.tags, {
    Name = var.redis_subnet_group_name
  })
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.replication_group_id
  description          = "Redis replication group for ECS microservices"

  engine         = "redis"
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = 6379

  num_cache_clusters = var.num_cache_clusters

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [var.redis_sg_id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled           = var.multi_az_enabled

  tags = merge(var.tags, {
    Name = var.replication_group_id
  })
}