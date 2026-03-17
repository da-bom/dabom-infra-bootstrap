variable "project" {
  description = "프로젝트 이름 (리소스 네이밍에 사용)"
  type        = string
  default     = "dabom"
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "admin_cidr_blocks" {
  description = "RDS, Redis, 모니터링 서버에 접근 가능한 관리자 IP CIDR 목록"
  type        = list(string)
}

variable "github_repo_patterns" {
  description = "GitHub Actions OIDC 신뢰 정책에 허용할 리포지토리 패턴 목록 (예: repo:da-bom/*:ref:refs/heads/main)"
  type        = list(string)
}

variable "tfc_organization" {
  description = "Terraform Cloud 조직 이름"
  type        = string
}
