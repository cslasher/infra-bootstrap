output "state_bucket_name" {
  description = "Name of the S3 bucket used to store Terraform state."
  value       = aws_s3_bucket.tf_state.id
}

output "state_bucket_region" {
  description = "AWS region where the state bucket was created."
  value       = var.aws_region
}

output "example_backend_config" {
  description = "Example backend block to paste into other Terraform projects."
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.tf_state.id}"
        key          = "project-name/env/terraform.tfstate"
        region       = "${var.aws_region}"
        encrypt      = true
        use_lockfile = true
      }
    }
  EOT
}
