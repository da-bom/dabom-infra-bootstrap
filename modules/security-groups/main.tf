# 보안 그룹 모듈: 순환 의존성 방지를 위해 모든 SG를 한 모듈에서 관리
# ALB → ECS → RDS/Redis/MSK 흐름에 맞게 계층적으로 구성

# ALB 보안 그룹: 인터넷에서 HTTP/HTTPS 트래픽 수신
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "ALB: 인터넷에서 HTTP/HTTPS 인바운드 허용"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-alb-sg"
  }
}

# ECS 보안 그룹: ALB에서 오는 트래픽만 허용
resource "aws_security_group" "ecs" {
  name        = "${var.project}-ecs-sg"
  description = "ECS 태스크: ALB에서 오는 모든 트래픽 허용"
  vpc_id      = var.vpc_id

  ingress {
    description     = "All traffic from ALB"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-ecs-sg"
  }
}

# RDS 보안 그룹: ECS 태스크와 관리자 IP에서만 MySQL 접근 허용
resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "RDS MySQL: ECS 태스크 및 관리자 IP에서만 3306 허용"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from ECS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  ingress {
    description = "MySQL from admin IPs"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-rds-sg"
  }
}

# Redis 보안 그룹: ECS 태스크와 관리자 IP에서만 Redis 접근 허용
resource "aws_security_group" "redis" {
  name        = "${var.project}-redis-sg"
  description = "Redis: ECS 태스크 및 관리자 IP에서만 6379 허용"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from ECS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  ingress {
    description = "Redis from admin IPs"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-redis-sg"
  }
}

# MSK(Kafka) 보안 그룹: ECS 태스크에서만 Kafka 브로커 접근 허용
# 9092: PLAINTEXT, 9094: TLS
resource "aws_security_group" "msk" {
  name        = "${var.project}-msk-sg"
  description = "MSK Kafka: ECS 태스크에서만 9092(PLAINTEXT)/9094(TLS) 허용"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Kafka PLAINTEXT from ECS"
    from_port       = 9092
    to_port         = 9092
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  ingress {
    description     = "Kafka TLS from ECS"
    from_port       = 9094
    to_port         = 9094
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-msk-sg"
  }
}

# 모니터링 서버 보안 그룹 (Grafana + OpenTelemetry Collector + Grafana Alloy)
# 관리자 IP: Grafana UI(80), OTLP(4317/4318), Alloy UI(12345), SSH(22)
# ECS 태스크: OTLP 텔레메트리 데이터 전송(4317/4318)
resource "aws_security_group" "monitor" {
  name        = "${var.project}-monitor-sg"
  description = "모니터링 서버: Grafana, OTLP Collector, Alloy UI, SSH"
  vpc_id      = var.vpc_id

  ingress {
    description = "Grafana UI from admin IPs"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  ingress {
    description = "OTLP gRPC from admin IPs"
    from_port   = 4317
    to_port     = 4317
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  ingress {
    description = "OTLP HTTP from admin IPs"
    from_port   = 4318
    to_port     = 4318
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  ingress {
    description     = "OTLP gRPC from ECS services"
    from_port       = 4317
    to_port         = 4317
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  ingress {
    description     = "OTLP HTTP from ECS services"
    from_port       = 4318
    to_port         = 4318
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  ingress {
    description = "Grafana Alloy UI from admin IPs"
    from_port   = 12345
    to_port     = 12345
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  ingress {
    description = "SSH from admin IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-monitor-sg"
  }
}
