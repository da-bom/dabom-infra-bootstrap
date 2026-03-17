variable "project" {
  description = "프로젝트 이름"
  type        = string
}

variable "vpc_id" {
  description = "보안 그룹을 생성할 VPC ID"
  type        = string
}

variable "admin_cidr_blocks" {
  description = "관리자 접근 허용 IP CIDR 목록 (RDS, Redis, 모니터링 서버 직접 접근용)"
  type        = list(string)
}
