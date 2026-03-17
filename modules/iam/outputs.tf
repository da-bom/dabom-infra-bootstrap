output "ecs_task_execution_role_arn" {
  description = "ECS 태스크 실행 롤 ARN (ECR 이미지 풀, CloudWatch 로그 등)"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arns" {
  description = "서비스별 ECS 태스크 롤 ARN 맵 (애플리케이션 코드가 AWS 리소스 접근 시 사용)"
  value = {
    api-core           = aws_iam_role.ecs_task_api_core.arn
    processor-usage    = aws_iam_role.ecs_task_processor_usage.arn
    api-notification   = aws_iam_role.ecs_task_api_notification.arn
    batch              = aws_iam_role.ecs_task_batch.arn
  }
}

output "github_actions_role_arn" {
  description = "GitHub Actions CI/CD 파이프라인용 OIDC 롤 ARN"
  value       = aws_iam_role.github_actions_ecr_deploy.arn
}
