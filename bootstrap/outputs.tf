output "ecr_repository_urls" {
  value = {
    for service, repo in aws_ecr_repository.services :
    service => repo.repository_url
  }
}

output "github_actions_role_arn" {
  value = aws_iam_role.ecs_microservices_github_actions.arn
}

output "terraform_state_bucket" {
  value = aws_s3_bucket.terraform_state.bucket
}