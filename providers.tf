terraform {
  required_version = ">= 1.7.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Terraform Cloud 백엔드: 상태 파일을 원격으로 관리하여 팀 협업 지원
  # organization 값은 리터럴이어야 함 (cloud 블록은 변수 참조 불가)
  cloud {
    organization = "dabom" # TODO: 실제 조직명으로 변경

    workspaces {
      name = "dabom-infra-bootstrap"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # 모든 리소스에 공통 태그 적용: 비용 추적 및 리소스 관리 용이성을 위해
  default_tags {
    tags = {
      Project     = "dabom"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}
