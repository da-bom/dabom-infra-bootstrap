# IAM 모듈: ECS 태스크 롤 및 GitHub Actions OIDC 롤 관리
# 최소 권한 원칙(Principle of Least Privilege)에 따라 서비스별로 롤을 분리

locals {
  # ECS 태스크 신뢰 정책: ecs-tasks 서비스가 이 롤을 Assume할 수 있도록 허용
  ecs_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  # 서비스별 태스크 롤: SSM Parameter Store에서 설정값을 읽을 수 있는 권한만 부여
  ssm_inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/${var.project}/*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# ECS 태스크 실행 롤 (Task Execution Role)
# ECR 이미지 풀, CloudWatch 로그 전송, SSM 파라미터 조회 권한
# ─────────────────────────────────────────────
resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.project}-ecs-task-execution-role"
  assume_role_policy = local.ecs_trust_policy

  tags = {
    Name = "${var.project}-ecs-task-execution-role"
  }
}

# AWS 관리형 정책: ECR 이미지 풀 + CloudWatch Logs 전송 기본 권한
resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 인라인 정책: SSM Parameter Store 조회 + KMS 복호화
# /dabom/* 경로의 파라미터만 접근 가능하도록 리소스 범위 제한
resource "aws_iam_role_policy" "ecs_task_execution_ssm" {
  name = "${var.project}-ecs-task-execution-ssm"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/${var.project}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = "*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# 서비스별 ECS 태스크 롤 (Task Role)
# 애플리케이션 코드가 실행 중 AWS 리소스에 접근할 때 사용
# ─────────────────────────────────────────────

resource "aws_iam_role" "ecs_task_api_core" {
  name               = "${var.project}-ecs-task-role-api-core"
  assume_role_policy = local.ecs_trust_policy

  tags = {
    Name = "${var.project}-ecs-task-role-api-core"
  }
}

resource "aws_iam_role_policy" "ecs_task_api_core_ssm" {
  name   = "${var.project}-ecs-task-api-core-ssm"
  role   = aws_iam_role.ecs_task_api_core.id
  policy = local.ssm_inline_policy
}

resource "aws_iam_role" "ecs_task_processor_usage" {
  name               = "${var.project}-ecs-task-role-processor-usage"
  assume_role_policy = local.ecs_trust_policy

  tags = {
    Name = "${var.project}-ecs-task-role-processor-usage"
  }
}

resource "aws_iam_role_policy" "ecs_task_processor_usage_ssm" {
  name   = "${var.project}-ecs-task-processor-usage-ssm"
  role   = aws_iam_role.ecs_task_processor_usage.id
  policy = local.ssm_inline_policy
}

resource "aws_iam_role" "ecs_task_api_notification" {
  name               = "${var.project}-ecs-task-role-api-notification"
  assume_role_policy = local.ecs_trust_policy

  tags = {
    Name = "${var.project}-ecs-task-role-api-notification"
  }
}

resource "aws_iam_role_policy" "ecs_task_api_notification_ssm" {
  name   = "${var.project}-ecs-task-api-notification-ssm"
  role   = aws_iam_role.ecs_task_api_notification.id
  policy = local.ssm_inline_policy
}

resource "aws_iam_role" "ecs_task_batch_core" {
  name               = "${var.project}-ecs-task-role-batch-core"
  assume_role_policy = local.ecs_trust_policy

  tags = {
    Name = "${var.project}-ecs-task-role-batch-core"
  }
}

resource "aws_iam_role_policy" "ecs_task_batch_core_ssm" {
  name   = "${var.project}-ecs-task-batch-core-ssm"
  role   = aws_iam_role.ecs_task_batch_core.id
  policy = local.ssm_inline_policy
}

# ─────────────────────────────────────────────
# GitHub Actions OIDC 설정
# 장기 자격 증명(Access Key) 없이 단기 토큰으로 AWS 접근 가능
# ─────────────────────────────────────────────

# GitHub Actions OIDC 제공자 등록
# thumbprint_list: GitHub의 TLS 인증서 지문 (변경 시 업데이트 필요)
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name = "${var.project}-github-actions-oidc"
  }
}

# GitHub Actions ECR 배포 롤: CI/CD 파이프라인에서 이미지 빌드/배포 시 사용
resource "aws_iam_role" "github_actions_ecr_deploy" {
  name = "${var.project}-github-actions-ecr-deploy"

  # 신뢰 정책: 지정된 GitHub 리포지토리에서만 이 롤을 Assume 가능
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = var.github_repo_patterns
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project}-github-actions-ecr-deploy"
  }
}

# GitHub Actions 인라인 정책: ECR 이미지 푸시 + ECS 서비스 업데이트 권한
resource "aws_iam_role_policy" "github_actions_ecr_deploy" {
  name = "${var.project}-github-actions-ecr-deploy-policy"
  role = aws_iam_role.github_actions_ecr_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        # ecr:GetAuthorizationToken은 리소스 수준 제한 불가 (AWS 제약)
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = var.ecr_repository_arns
      },
      {
        Sid    = "ECSDeployment"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMPassRole"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        # ECS 태스크 등록 시 태스크 실행 롤과 태스크 롤을 Pass할 수 있어야 함
        Resource = [
          aws_iam_role.ecs_task_execution.arn,
          aws_iam_role.ecs_task_api_core.arn,
          aws_iam_role.ecs_task_processor_usage.arn,
          aws_iam_role.ecs_task_api_notification.arn,
          aws_iam_role.ecs_task_batch_core.arn
        ]
      }
    ]
  })
}
