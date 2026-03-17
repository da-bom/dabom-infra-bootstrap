output "repository_urls" {
  description = "ECR 리포지토리 이름 → URL 맵 (Docker 이미지 푸시/풀에 사용)"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "repository_arns" {
  description = "ECR 리포지토리 ARN 목록 (IAM 정책 리소스 지정에 사용)"
  value       = [for repo in aws_ecr_repository.this : repo.arn]
}
