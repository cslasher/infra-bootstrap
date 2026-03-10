variable "aws_region" {
  description = "AWS region where the state bucket will be created."
  type        = string
  default     = "ap-northeast-1"
}

variable "bucket_prefix" {
  description = "Prefix for the S3 state bucket name. A random suffix will be appended to ensure global uniqueness."
  type        = string
  default     = "infra-tf-state"
}
