terraform {
  backend "s3" {
    bucket         = "my-terraform-bucket-muna"
    key            = "bootstrap/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    use_lockfile   = true
  }
}