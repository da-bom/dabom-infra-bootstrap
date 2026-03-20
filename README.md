# dabom-infra-bootstrap

DABOM 프로젝트의 AWS 인프라 기반 레이어. VPC, 보안 그룹, IAM 롤, ECR 리포지토리 등 전체 인프라 스택의 기초를 담당합니다. `dabom-infra-platform`과 `dabom-infra-monitor` 레이어가 이 레이어의 outputs을 `terraform_remote_state`로 참조합니다.

## 아키텍처

```
dabom-infra-bootstrap (이 레포)
        |
        v
dabom-infra-platform (ECS, ALB, MSK, Redis, RDS)
        |
        v
dabom-infra-monitor (EC2 모니터링 VM)
```

이 레이어는 의존성이 없는 **최하위 기초 레이어**입니다. 다른 모든 레이어의 네트워크, 보안, IAM 기반을 제공합니다.

## 모듈 구성

### modules/vpc

전체 인프라의 네트워크 기반입니다. NAT Gateway 없이 **퍼블릭 서브넷만** 사용하여 비용을 최소화합니다.

| 리소스 | CIDR 또는 설정 | 설명 |
|--------|-------------|------|
| VPC | 10.0.0.0/16 | 프로젝트 메인 VPC |
| Public Subnet 1 | 10.0.1.0/24 (ap-northeast-2a) | 고가용성을 위해 2개 AZ에 분산 |
| Public Subnet 2 | 10.0.2.0/24 (ap-northeast-2c) | 고가용성을 위해 2개 AZ에 분산 |
| Internet Gateway | - | VPC와 인터넷 간 트래픽의 진입점 |
| Route Table | 0.0.0.0/0 → IGW | 모든 아웃바운드 트래픽을 인터넷으로 라우팅 |

**특징:**
- `map_public_ip_on_launch=true`: 인스턴스 시작 시 자동으로 퍼블릭 IP 할당
- NAT Gateway 없음: 모든 리소스(ECS, RDS, Redis, MSK)를 퍼블릭 서브넷에 배치하여 비용 절감
- 2개 AZ에 걸쳐 배치하여 가용성 보장

### modules/security-groups

6개의 보안 그룹을 **한 모듈에서 중앙 집중식으로 관리**합니다. 순환 의존성을 방지하고, ALB → ECS → RDS/Redis/MSK 계층 구조를 명확하게 표현합니다.

#### alb-sg (ALB 보안 그룹)

| 방향 | 포트 | 프로토콜 | 소스 | 설명 |
|------|------|--------|------|------|
| Inbound | 80 | TCP | 0.0.0.0/0 | HTTP: 인터넷에서 접근 가능 |
| Inbound | 443 | TCP | 0.0.0.0/0 | HTTPS: 인터넷에서 접근 가능 |
| Outbound | 모두 | - | 0.0.0.0/0 | 모든 아웃바운드 허용 |

#### ecs-sg (ECS Fargate 태스크 보안 그룹)

| 방향 | 포트 | 프로토콜 | 소스 | 설명 |
|------|------|--------|------|------|
| Inbound | 모두 | - | alb-sg | ALB에서 오는 모든 트래픽 허용 |
| Outbound | 모두 | - | 0.0.0.0/0 | 모든 아웃바운드 허용 |

#### rds-sg (RDS MySQL 보안 그룹)

| 방향 | 포트 | 프로토콜 | 소스 | 설명 |
|------|------|--------|------|------|
| Inbound | 3306 | TCP | ecs-sg | ECS 태스크에서 MySQL 접근 |
| Inbound | 3306 | TCP | admin_cidr_blocks | 관리자 IP에서 접근 (RDS 관리) |
| Outbound | 모두 | - | 0.0.0.0/0 | 모든 아웃바운드 허용 |

#### redis-sg (ElastiCache Redis 보안 그룹)

| 방향 | 포트 | 프로토콜 | 소스 | 설명 |
|------|------|--------|------|------|
| Inbound | 6379 | TCP | ecs-sg | ECS 태스크에서 Redis 접근 |
| Inbound | 6379 | TCP | admin_cidr_blocks | 관리자 IP에서 접근 (Redis 관리) |
| Outbound | 모두 | - | 0.0.0.0/0 | 모든 아웃바운드 허용 |

#### msk-sg (Amazon MSK Kafka 보안 그룹)

| 방향 | 포트 | 프로토콜 | 소스 | 설명 |
|------|------|--------|------|------|
| Inbound | 9092 | TCP | ecs-sg | ECS 태스크에서 Kafka PLAINTEXT 접근 |
| Inbound | 9094 | TCP | ecs-sg | ECS 태스크에서 Kafka TLS 접근 |
| Inbound | 9092 | TCP | monitor-sg | 모니터링 서버에서 Kafka PLAINTEXT 접근 |
| Inbound | 9094 | TCP | monitor-sg | 모니터링 서버에서 Kafka TLS 접근 |
| Outbound | 모두 | - | 0.0.0.0/0 | 모든 아웃바운드 허용 |

#### monitor-sg (모니터링 EC2 보안 그룹)

모니터링 스택(Grafana + OpenTelemetry Collector + Grafana Alloy)을 실행하는 EC2 인스턴스용입니다.

| 방향 | 포트 | 프로토콜 | 소스 | 설명 |
|------|------|--------|------|------|
| Inbound | 80 | TCP | admin_cidr_blocks | Grafana UI 접근 |
| Inbound | 4317 | TCP | admin_cidr_blocks | OTLP gRPC: 관리자에서 수동 설정 |
| Inbound | 4318 | TCP | admin_cidr_blocks | OTLP HTTP: 관리자에서 수동 설정 |
| Inbound | 4317 | TCP | ecs-sg | OTLP gRPC: ECS 태스크에서 텔레메트리 전송 |
| Inbound | 4318 | TCP | ecs-sg | OTLP HTTP: ECS 태스크에서 텔레메트리 전송 |
| Inbound | 12345 | TCP | admin_cidr_blocks | Grafana Alloy UI 접근 |
| Inbound | 22 | TCP | admin_cidr_blocks | SSH: 서버 관리 |
| Outbound | 모두 | - | 0.0.0.0/0 | 모든 아웃바운드 허용 |

### modules/iam

ECS 태스크 실행 롤, 서비스별 태스크 롤, GitHub Actions OIDC 롤을 관리합니다. **최소 권한 원칙(Principle of Least Privilege)**을 따릅니다.

#### ECS Task Execution Role

ECS가 태스크를 시작하기 위해 필요한 권한입니다.

| 권한 | 리소스 범위 | 설명 |
|------|-----------|------|
| ecr:GetDownloadUrlForLayer, ecr:BatchGetImage, ecr:BatchCheckLayerAvailability | - | ECR에서 컨테이너 이미지 풀 |
| logs:CreateLogStream, logs:PutLogEvents | - | CloudWatch Logs에 로그 기록 |
| ssm:GetParameters, ssm:GetParameter, ssm:GetParametersByPath | arn:aws:ssm:*:*:parameter/dabom/* | SSM Parameter Store에서 설정값 조회 |
| kms:Decrypt | * | KMS로 암호화된 파라미터 복호화 |

#### 서비스별 ECS Task Role

애플리케이션 코드가 실행 중 AWS 리소스에 접근할 때 사용하는 롤입니다. 모든 서비스가 동일한 권한을 가집니다.

**서비스 목록:**
- `ecs-task-role-api-core`: API 코어 서비스
- `ecs-task-role-processor-usage`: 사용량 처리 배치
- `ecs-task-role-api-notification`: 알림 API
- `ecs-task-role-batch-core`: 핵심 배치 작업

**권한:**
- `ssm:GetParameters, ssm:GetParameter, ssm:GetParametersByPath`: /dabom/* 경로의 파라미터 조회
- `ssmmessages:CreateControlChannel, ssmmessages:CreateDataChannel, ssmmessages:OpenControlChannel, ssmmessages:OpenDataChannel`: ECS Exec로 태스크에 직접 접속 (디버깅/관리용)

#### GitHub Actions OIDC Role

CI/CD 파이프라인에서 AWS 리소스에 접근하기 위한 역할입니다. 장기 자격 증명(Access Key) 없이 단기 토큰으로 인증합니다.

| 권한 | 리소스 범위 | 설명 |
|------|-----------|------|
| ecr:GetAuthorizationToken | * | ECR 로그인 토큰 취득 |
| ecr:BatchCheckLayerAvailability, ecr:GetDownloadUrlForLayer, ecr:BatchGetImage, ecr:PutImage, ecr:InitiateLayerUpload, ecr:UploadLayerPart, ecr:CompleteLayerUpload | ECR 리포지토리 | 이미지 빌드 및 푸시 |
| ecs:UpdateService, ecs:DescribeServices, ecs:DescribeTaskDefinition, ecs:RegisterTaskDefinition | * | ECS 서비스 업데이트 및 태스크 정의 등록 |
| iam:PassRole | ecs_task_execution_role, ecs_task_role_* | 태스크 롤을 ECS에 전달 |

**신뢰 정책:** `github_repo_patterns` 변수에 지정된 GitHub 리포지토리에서만 이 롤을 Assume 가능합니다.

**GitHub OIDC 제공자:**
- URL: `https://token.actions.githubusercontent.com`
- TLS 인증서 지문: `6938fd4d98bab03faadb97b34396831e3780aea1`, `1c58a3a8518e8759bf075b76b750d4f2df264fcd`

### modules/ecr

서비스별 컨테이너 이미지를 저장하는 4개의 ECR 리포지토리를 관리합니다.

| 리포지토리 | 설명 |
|----------|------|
| dabom/api-core | 핵심 API 서비스 이미지 |
| dabom/processor-usage | 사용량 처리 배치 이미지 |
| dabom/api-notification | 알림 API 이미지 |
| dabom/batch-core | 핵심 배치 작업 이미지 |

**설정:**
- `image_tag_mutability`: MUTABLE (동일 태그로 이미지 덮어쓰기 가능, `latest` 태그 사용)
- `force_delete`: true (이미지가 있어도 리포지토리 강제 삭제 가능)
- `scan_on_push`: true (푸시 시 자동으로 취약점 스캔)

**라이프사이클 정책:**

| 규칙 | 조건 | 동작 | 목적 |
|------|------|------|------|
| 1 | 태그 없는 이미지가 3일 이상 경과 | 삭제 | 빌드 캐시 레이어 정리, 스토리지 비용 절감 |
| 2 | 태그된 이미지(v 접두사)가 5개 초과 | 오래된 것부터 삭제 | 이전 버전 최대 5개만 유지, 디스크 관리 |

## 배포

### 전제 조건

1. AWS 계정 및 자격 증명 설정
2. Terraform 1.7.5 이상
3. AWS Provider 5.0 이상

### 초기 설정

#### 1단계: terraform.tfvars 수정

`terraform.tfvars` 파일을 자신의 환경에 맞게 수정합니다.

```hcl
project            = "dabom"              # 프로젝트 이름 (기본값 유지 권장)
admin_cidr_blocks  = ["203.0.113.0/24"]   # 실제 관리자 IP CIDR로 변경
github_repo_patterns = [
  "repo:da-bom/*:ref:refs/heads/main",
  "repo:da-bom/*:ref:refs/heads/dev"
]                                         # GitHub Actions가 실행되는 리포지토리 패턴
tfc_organization   = "your-org"           # 실제 Terraform Cloud 조직명으로 변경
```

**admin_cidr_blocks 설명:**
- RDS, Redis, 모니터링 서버에 접근할 수 있는 관리자 IP 범위
- 예: 회사 네트워크 IP, VPN 서버 IP, 개발자 개인 IP (CIDR 표기법)
- 주의: 0.0.0.0/0은 프로덕션에서 사용하지 않음 (보안 위험)

**github_repo_patterns 설명:**
- GitHub Actions OIDC 신뢰 정책에 허용할 리포지토리 패턴
- 형식: `repo:<github-org>/<repo-name>:ref:<ref-path>`
- 예: `repo:da-bom/api-core:ref:refs/heads/main`
- 여러 리포지토리를 허용하려면 리스트에 추가

#### 2단계: providers.tf 수정

`providers.tf` 파일의 `cloud` 블록에서 조직명을 수정합니다.

```hcl
terraform {
  required_version = ">= 1.7.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  cloud {
    organization = "your-org"  # Terraform Cloud 조직명으로 변경

    workspaces {
      name = "dabom-infra-bootstrap"
    }
  }
}
```

**참고:** Terraform Cloud `cloud` 블록은 변수를 참조할 수 없으므로 수동 편집 필요.

#### 3단계: Terraform Cloud 로그인

Terraform Cloud를 사용하는 경우 인증 토큰이 필요합니다.

```bash
terraform login
```

대화식 프롬프트에서 Terraform Cloud API 토큰을 입력합니다.

### 배포 실행

```bash
# 1. Terraform 초기화 (플러그인 다운로드, 백엔드 설정)
terraform init

# 2. 변경 사항 미리보기 (dry-run)
terraform plan

# 3. 인프라 생성
terraform apply
```

`terraform apply` 실행 후:
- 프롬프트에서 `yes`를 입력하여 변경 사항 확인 및 적용
- 약 2-5분 내에 완료
- 완료 후 모든 output 값이 표시됨

### 배포 후 확인

배포 완료 후 AWS 콘솔 또는 CLI로 리소스 확인:

```bash
# VPC 정보 조회
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=dabom"

# 보안 그룹 확인
aws ec2 describe-security-groups --filters "Name=tag:Project,Values=dabom"

# ECR 리포지토리 확인
aws ecr describe-repositories --query 'repositories[*].[repositoryName, repositoryUri]'

# IAM 롤 확인
aws iam list-roles --query 'Roles[?contains(RoleName, `dabom`)].{Name:RoleName, Arn:Arn}'
```

## 변수

| 변수 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `project` | string | 아니오 | "dabom" | 프로젝트 이름 (리소스 네이밍에 사용) |
| `aws_region` | string | 아니오 | "ap-northeast-2" | AWS 리전 |
| `admin_cidr_blocks` | list(string) | 예 | - | RDS, Redis, 모니터링 서버에 접근 가능한 관리자 IP CIDR 목록 |
| `github_repo_patterns` | list(string) | 예 | - | GitHub Actions OIDC 신뢰 정책에 허용할 리포지토리 패턴 |
| `tfc_organization` | string | 예 | - | Terraform Cloud 조직 이름 |

### VPC 모듈 변수 (추가 커스터마이징용)

`terraform.tfvars`에 추가하여 오버라이드 가능:

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `vpc_cidr` | string | "10.0.0.0/16" | VPC CIDR 블록 |
| `public_subnet_cidrs` | list(string) | ["10.0.1.0/24", "10.0.2.0/24"] | 퍼블릭 서브넷 CIDR 목록 |
| `availability_zones` | list(string) | ["ap-northeast-2a", "ap-northeast-2c"] | AZ 목록 |

### ECR 모듈 변수 (추가 커스터마이징용)

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `repository_names` | list(string) | ["dabom/api-core", "dabom/processor-usage", "dabom/api-notification", "dabom/batch-core"] | ECR 리포지토리 이름 목록 |

## Outputs

다음 outputs은 상위 레이어(`dabom-infra-platform`, `dabom-infra-monitor`)에서 `terraform_remote_state`로 참조합니다.

### VPC Outputs

| Output | 설명 |
|--------|------|
| `vpc_id` | VPC ID |
| `public_subnet_ids` | 퍼블릭 서브넷 ID 목록 |
| `igw_id` | 인터넷 게이트웨이 ID |

### Security Group Outputs

| Output | 설명 |
|--------|------|
| `alb_sg_id` | ALB 보안 그룹 ID |
| `ecs_sg_id` | ECS 보안 그룹 ID |
| `rds_sg_id` | RDS 보안 그룹 ID |
| `redis_sg_id` | Redis 보안 그룹 ID |
| `msk_sg_id` | MSK(Kafka) 보안 그룹 ID |
| `monitor_sg_id` | 모니터링 서버 보안 그룹 ID |

### IAM Outputs

| Output | 설명 |
|--------|------|
| `ecs_task_execution_role_arn` | ECS 태스크 실행 롤 ARN |
| `ecs_task_role_arns` | 서비스별 ECS 태스크 롤 ARN 맵 (예: `ecs_task_role_arns["api-core"]`) |
| `github_actions_role_arn` | GitHub Actions OIDC 롤 ARN |

### ECR Outputs

| Output | 설명 |
|--------|------|
| `ecr_repository_urls` | ECR 리포지토리 이름 → URL 맵 (예: `ecr_repository_urls["dabom/api-core"]`) |

## 주요 설계 결정사항

### 1. 퍼블릭 서브넷만 사용 (NAT Gateway 없음)

**이유:**
- NAT Gateway는 월 약 $32 + 데이터 전송료
- ECS Fargate, RDS, Redis, MSK 모두 퍼블릭 IP로 배치
- 개발/테스트 환경에서 빠른 네트워크 속도 필요

**보안:**
- 보안 그룹으로 접근을 엄격하게 제한하므로 안전성 확보
- 필요시 프로덕션에서 NAT Gateway 추가 가능

### 2. 보안 그룹의 중앙 집중식 관리

**이유:**
- 순환 의존성 방지 (security group to security group reference)
- 모든 SG를 한 모듈에서 생성하므로 ID 참조 가능
- 계층적 구조 명확화 (ALB → ECS → RDS/Redis/MSK)

### 3. 서비스별 IAM 롤 분리

**이유:**
- 각 서비스가 필요한 권한만 가지도록 제한 (최소 권한 원칙)
- 향후 특정 서비스에만 새로운 권한 추가 시 다른 서비스에 영향 없음
- 보안 감사 및 모니터링 용이

### 4. GitHub Actions OIDC 사용 (Access Key 없음)

**이유:**
- 장기 자격 증명(Access Key)을 GitHub에 저장하지 않음
- 깃허브에서 자동으로 단기 토큰 생성 및 관리
- 유출 시 피해 범위 제한

### 5. ECR 라이프사이클 정책

**이유:**
- 태그 없는 이미지 3일 후 삭제: 빌드 캐시 자동 정리
- 태그된 이미지 최대 5개 유지: 이전 버전으로 롤백 가능
- 스토리지 비용 최적화

## 문제 해결

### terraform init 실패

```
Error: Invalid or missing values for terraform cloud
```

**해결:**
1. `providers.tf`의 `cloud { organization = "..." }` 확인
2. `terraform login`으로 Terraform Cloud 토큰 설정

### terraform apply 실패

```
Error: Error requesting temporary security credentials
```

**해결:**
1. AWS 자격 증명 설정 확인: `aws sts get-caller-identity`
2. 환경 변수 `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` 확인
3. IAM 사용자에 필요한 권한 확인

### 보안 그룹 생성 실패

```
Error: InvalidGroup.InUse - The security group is in use
```

**해결:**
1. AWS 콘솔에서 기존 SG 확인
2. 기존 SG를 `terraform import`하거나 다른 이름으로 생성
3. 또는 기존 리소스 수동 삭제 후 재시도

## 유지보수

### 상태 파일 관리

상태 파일은 Terraform Cloud에서 원격으로 관리됩니다.

```bash
# 상태 파일 내용 확인 (로컬에서)
terraform state list
terraform state show module.vpc.aws_vpc.main

# 상태 백업 (권장)
terraform state pull > backup.tfstate
```

### 리소스 추가/제거

리소스를 추가하거나 제거할 때:

```bash
# 1. terraform 파일 수정
# 2. 계획 확인
terraform plan

# 3. 변경 적용
terraform apply
```

### 버전 관리

필요시 AWS Provider 버전 업그레이드:

```hcl
# providers.tf 수정
aws = {
  source  = "hashicorp/aws"
  version = "~> 5.5"  # 5.5.0 이상 사용
}
```

```bash
terraform init -upgrade
terraform plan
terraform apply
```

## 참고 자료

- [AWS Terraform Provider 문서](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Cloud 문서](https://developer.hashicorp.com/terraform/cloud-docs)
- [Terraform 상태 관리](https://developer.hashicorp.com/terraform/language/state)

## 라이선스

내부용 Terraform 코드입니다.
