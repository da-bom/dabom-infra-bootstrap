# VPC: 전체 인프라의 네트워크 기반
# NAT Gateway 없이 퍼블릭 서브넷만 사용하여 비용 절감
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project}-vpc"
  }
}

# 퍼블릭 서브넷: 고가용성을 위해 2개 AZ에 분산 배치
# map_public_ip_on_launch=true: 인스턴스 시작 시 자동으로 퍼블릭 IP 할당
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-public-subnet-${count.index + 1}"
  }
}

# 인터넷 게이트웨이: VPC와 인터넷 간 통신의 진입점
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-igw"
  }
}

# 퍼블릭 라우팅 테이블: 모든 트래픽(0.0.0.0/0)을 IGW로 라우팅
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project}-public-rt"
  }
}

# 라우팅 테이블을 모든 퍼블릭 서브넷에 연결
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
