variable "project" {
  description = "프로젝트 이름"
  type        = string
}

variable "github_repo_patterns" {
  description = "GitHub Actions OIDC 신뢰 정책에 허용할 리포지토리 패턴 목록"
  type        = list(string)
}

variable "ecr_repository_arns" {
  description = "GitHub Actions 배포 롤에 접근 권한을 부여할 ECR 리포지토리 ARN 목록"
  type        = list(string)
}
