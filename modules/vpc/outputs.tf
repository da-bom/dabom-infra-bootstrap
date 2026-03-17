output "vpc_id" {
  description = "생성된 VPC의 ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록"
  value       = aws_subnet.public[*].id
}

output "igw_id" {
  description = "인터넷 게이트웨이 ID"
  value       = aws_internet_gateway.main.id
}
