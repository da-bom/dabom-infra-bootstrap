variable "project" {
  description = "프로젝트 이름"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 목록 (NAT Gateway 없이 모든 리소스를 퍼블릭 서브넷에 배치)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "서브넷을 배치할 가용 영역 목록 (고가용성을 위해 2개 AZ 사용)"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}
