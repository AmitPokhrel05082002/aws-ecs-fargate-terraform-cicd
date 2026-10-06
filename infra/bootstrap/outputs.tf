output "state_bucket" {
  description = "Pass this to `make init` as STATE_BUCKET (the Makefile derives it automatically)."
  value       = aws_s3_bucket.tfstate.bucket
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "ecr_push_role_arn" {
  value = aws_iam_role.ecr_push.arn
}

output "deploy_role_arns" {
  value = { for env, role in aws_iam_role.deploy : env => role.arn }
}

output "github_setup_commands" {
  description = "Run these with the GitHub CLI after creating the GitHub environments."
  value       = <<-EOT
    gh variable set AWS_REGION --body "${var.region}"
    gh variable set PROJECT_NAME --body "${var.project}"
    gh variable set ECR_REGISTRY --body "${split("/", aws_ecr_repository.app.repository_url)[0]}"
    gh variable set ECR_PUSH_ROLE_ARN --body "${aws_iam_role.ecr_push.arn}"
    %{~for env in var.environments}
    gh variable set AWS_DEPLOY_ROLE_ARN --env ${env} --body "${aws_iam_role.deploy[env].arn}"
    %{~endfor}
  EOT
}
