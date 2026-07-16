locals {
  subnets = {
    "public-1" = { cidr = "10.0.1.0/24", az = "eu-west-2a", tier = "public" }
    "public-2" = { cidr = "10.0.2.0/24", az = "eu-west-2b", tier = "public" }

    "app-1" = { cidr = "10.0.11.0/24", az = "eu-west-2a", tier = "app" }
    "app-2" = { cidr = "10.0.12.0/24", az = "eu-west-2b", tier = "app" }

    "db-1" = { cidr = "10.0.21.0/24", az = "eu-west-2a", tier = "db" }
    "db-2" = { cidr = "10.0.22.0/24", az = "eu-west-2c", tier = "db" }
  }
}