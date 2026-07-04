terraform {
  backend "s3" {
    bucket       = "my-terraform-bucket-muna"
    key          = "secrets/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}