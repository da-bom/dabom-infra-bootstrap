output "alb_sg_id" {
  description = "ALB 보안 그룹 ID"
  value       = aws_security_group.alb.id
}

output "ecs_sg_id" {
  description = "ECS 태스크 보안 그룹 ID"
  value       = aws_security_group.ecs.id
}

output "rds_sg_id" {
  description = "RDS 보안 그룹 ID"
  value       = aws_security_group.rds.id
}

output "redis_sg_id" {
  description = "Redis 보안 그룹 ID"
  value       = aws_security_group.redis.id
}

output "msk_sg_id" {
  description = "MSK(Kafka) 보안 그룹 ID"
  value       = aws_security_group.msk.id
}

output "monitor_sg_id" {
  description = "모니터링 서버 보안 그룹 ID"
  value       = aws_security_group.monitor.id
}
