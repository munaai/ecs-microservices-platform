terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "custom-vpc" })
}

resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  map_public_ip_on_launch = each.value.tier == "public"

  tags = merge(var.tags, {
    Name = each.key
    Tier = each.value.tier
  })
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "custom-igw" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = merge(var.tags, { Name = "public-route-table" })
}

resource "aws_route_table_association" "public" {
  for_each = {
    for name, subnet in local.subnets :
    name => subnet
    if subnet.tier == "public"
  }

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "app_private" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, { Name = "app-private-route-table" })
}

resource "aws_route_table" "db_private" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, { Name = "db-private-route-table" })
}

resource "aws_route_table_association" "app_private" {
  for_each = {
    for name, subnet in local.subnets :
    name => subnet
    if subnet.tier == "app"
  }

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.app_private.id
}

resource "aws_route_table_association" "db_private" {
  for_each = {
    for name, subnet in local.subnets :
    name => subnet
    if subnet.tier == "db"
  }

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.db_private.id
}