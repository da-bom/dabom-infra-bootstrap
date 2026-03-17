# 루트 outputs: 상위 레이어(platform, monitor)에서
# terraform_remote_state로 참조할 수 있도록 모든 핵심 리소스 ID/ARN 노출

# ─── VPC ───────────────────────────────────────
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록 (AZ-a, AZ-c)"
  value       = module.vpc.public_subnet_ids
}

output "igw_id" {
  description = "인터넷 게이트웨이 ID"
  value       = module.vpc.igw_id
}

# ─── Security Groups ───────────────────────────
output "alb_sg_id" {
  description = "ALB 보안 그룹 ID"
  value       = module.security_groups.alb_sg_id
}

output "ecs_sg_id" {
  description = "ECS 태스크 보안 그룹 ID"
  value       = module.security_groups.ecs_sg_id
}

output "rds_sg_id" {
  description = "RDS 보안 그룹 ID"
  value       = module.security_groups.rds_sg_id
}

output "redis_sg_id" {
  description = "Redis 보안 그룹 ID"
  value       = module.security_groups.redis_sg_id
}

output "msk_sg_id" {
  description = "MSK(Kafka) 보안 그룹 ID"
  value       = module.security_groups.msk_sg_id
}

output "monitor_sg_id" {
  description = "모니터링 서버 보안 그룹 ID"
  value       = module.security_groups.monitor_sg_id
}

# ─── IAM ───────────────────────────────────────
output "ecs_task_execution_role_arn" {
  description = "ECS 태스크 실행 롤 ARN"
  value       = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arns" {
  description = "서비스별 ECS 태스크 롤 ARN 맵"
  value       = module.iam.ecs_task_role_arns
}

output "github_actions_role_arn" {
  description = "GitHub Actions CI/CD OIDC 롤 ARN"
  value       = module.iam.github_actions_role_arn
}

# ─── ECR ───────────────────────────────────────
output "ecr_repository_urls" {
  description = "ECR 리포지토리 이름 → URL 맵"
  value       = module.ecr.repository_urls
}
