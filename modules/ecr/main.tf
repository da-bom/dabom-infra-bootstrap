# ECR 리포지토리: 서비스별 컨테이너 이미지 저장소
# for_each를 사용하여 동일한 설정으로 여러 리포지토리를 일관되게 관리
resource "aws_ecr_repository" "this" {
  for_each = toset(var.repository_names)

  name                 = each.key
  image_tag_mutability = "MUTABLE" # 동일 태그로 이미지 덮어쓰기 허용 (latest 태그 사용 시 필요)
  force_delete         = true      # 이미지가 있어도 강제 삭제 가능 (개발/테스트 환경 정리 용이)

  image_scanning_configuration {
    scan_on_push = true # 푸시 시 자동 취약점 스캔으로 보안 강화
  }

  tags = {
    Name = each.key
  }
}

# 라이프사이클 정책: 이미지 관리 비용 절감
# - 태그된 이미지: 최대 5개 유지 (오래된 버전 자동 삭제)
# - 태그 없는 이미지: 3일 후 자동 삭제 (빌드 캐시 레이어 정리)
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 3 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 3
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only 5 most recent tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
