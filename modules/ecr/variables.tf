variable "repository_names" {
  description = "생성할 ECR 리포지토리 이름 목록"
  type        = list(string)
  default     = ["dabom/api-core", "dabom/processor-usage", "dabom/api-notification", "dabom/batch"]
}
