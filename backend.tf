# This bootstrap project uses a local backend because the remote S3 backend
# does not exist yet — this project is what creates it.
#
# After running `terraform apply`, configure all other Terraform projects to
# use the S3 bucket output by this project as their remote backend.
terraform {
  backend "local" {}
}
