# dabom-infra-bootstrap: 인프라 기반 레이어
# 이 워크스페이스는 플랫폼/모니터 레이어가 참조하는 핵심 리소스를 관리:
# VPC, 보안 그룹, IAM 롤, ECR 리포지토리

# VPC: 네트워크 기반 (퍼블릭 서브넷만, NAT Gateway 없음)
module "vpc" {
  source  = "./modules/vpc"
  project = var.project
}

# 보안 그룹: ALB → ECS → RDS/Redis/MSK/Monitor 계층 구조
module "security_groups" {
  source            = "./modules/security-groups"
  project           = var.project
  vpc_id            = module.vpc.vpc_id
  admin_cidr_blocks = var.admin_cidr_blocks
}

# ECR: 서비스별 컨테이너 이미지 레지스트리 (IAM 전에 생성하여 ARN 참조)
module "ecr" {
  source = "./modules/ecr"
}

# IAM: ECS 태스크 롤 및 GitHub Actions OIDC 롤
# ECR ARN을 GitHub Actions 배포 롤 정책에 포함
module "iam" {
  source               = "./modules/iam"
  project              = var.project
  github_repo_patterns = var.github_repo_patterns
  ecr_repository_arns  = module.ecr.repository_arns
}
