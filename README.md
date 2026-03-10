# infra-bootstrap

Terraform project that provisions the shared S3 bucket used to store Terraform
state for all infrastructure projects.

---

## What this project does

This project creates a single, long-lived S3 bucket that acts as the remote
backend for every other Terraform project in the organisation. It is run once
(or rarely) and is intentionally kept minimal.

Resources created:

| Resource                                             | Purpose                                       |
| ---------------------------------------------------- | --------------------------------------------- |
| `aws_s3_bucket`                                      | Stores all Terraform state files              |
| `aws_s3_bucket_versioning`                           | Retains previous state versions for rollback  |
| `aws_s3_bucket_server_side_encryption_configuration` | Encrypts state at rest (AES256)               |
| `aws_s3_bucket_public_access_block`                  | Blocks all public access                      |
| `aws_s3_bucket_policy`                               | Denies unencrypted uploads to the bucket      |
| `random_id`                                          | Generates a unique suffix for the bucket name |

No DynamoDB table is created. State locking is handled natively by Terraform's
S3 lockfile feature (`use_lockfile = true`), available since Terraform 1.7.

---

## Why remote state is required

By default Terraform stores state in a local `terraform.tfstate` file. This
causes problems when:

- Working from **multiple machines** (Mac, WSL, CI/CD) — each machine has its
  own copy of state, leading to drift and conflicts.
- **Collaborating** with a team — no single source of truth for what is
  currently deployed.
- Running **automated pipelines** — local state is lost between runs.

Storing state in S3 solves all of these: one bucket, one state file per
project/environment, accessible from anywhere.

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.7
- AWS credentials configured (e.g. `~/.aws/credentials`, environment variables,
  or an IAM role)
- Sufficient IAM permissions to create S3 buckets

---

## How to run

```bash
# 1. Initialise Terraform (local backend — no remote state needed yet)
terraform init

# 2. Preview what will be created
terraform plan

# 3. Apply — creates the S3 bucket
terraform apply
```

After `apply` completes, Terraform will print the bucket name:

```
Outputs:

state_bucket_name     = "infra-tf-state-a1b2c3d4"
state_bucket_region   = "ap-northeast-1"
example_backend_config = <<EOT
  terraform {
    backend "s3" {
      bucket       = "infra-tf-state-a1b2c3d4"
      key          = "project-name/env/terraform.tfstate"
      region       = "ap-northeast-1"
      encrypt      = true
      use_lockfile = true
    }
  }
EOT
```

---

## Configuring other projects to use this bucket

Copy the `example_backend_config` output into the Terraform project you want to
manage remotely. Replace `project-name/env` with the actual project and
environment name.

### State file layout inside the bucket

```
infra-tf-state-a1b2c3d4/
  ├── sylph/prod/terraform.tfstate
  ├── sylph/dev/terraform.tfstate
  ├── blog/prod/terraform.tfstate
  └── experiments/demo/terraform.tfstate
```

Each project+environment combination gets its own key (path) in the bucket, so
they are completely isolated from each other.

### Example backend block

```hcl
terraform {
  backend "s3" {
    bucket       = "infra-tf-state-a1b2c3d4"   # replace with your bucket name
    key          = "sylph/prod/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

After adding the backend block, run `terraform init` in that project to migrate
state to S3.

---

## Running Terraform from multiple machines

With the S3 backend configured, it is safe to run Terraform from a Mac, WSL,
or a CI/CD pipeline simultaneously. The `use_lockfile = true` option causes
Terraform to write a `.tflock` file to S3 during operations, preventing
concurrent applies from corrupting state.

---

## Security notes

- The bucket blocks all public access.
- Versioning is enabled — previous state files can be recovered from the S3
  console if needed.
- State is encrypted at rest with AES256.
- `prevent_destroy = true` is set on the bucket to guard against accidental
  `terraform destroy`.

### Important: Secrets in state files

Terraform state files may contain sensitive data such as database passwords, API
keys, and private IPs. Treat the state bucket with care:

- Never commit terraform state to version control
- Restrict bucket access to trusted IAM principals only
- Use `sensitive = true` in module outputs to avoid logging secrets
- Consider using AWS Secrets Manager or similar for sensitive values instead of
  storing them in state

---

## Optional Enhancements

The following improvements are not included to keep this bootstrap minimal, but
are worth considering for future iterations:

| Enhancement                           | Benefit                                                            | Cost               | Effort |
| ------------------------------------- | ------------------------------------------------------------------ | ------------------ | ------ |
| **Enable MFA Delete**                 | Extra protection against accidental version deletion               | None               | Low    |
| **Lifecycle policy**                  | Auto-deletes old versions after 30-90 days, reducing storage costs | Minimal            | Low    |
| **S3 access logging**                 | Audit trail of who accessed state files                            | New S3 bucket      | Medium |
| **KMS encryption (customer-managed)** | Better key audit trails, key rotation control                      | ~$1/month          | Medium |
| **CloudWatch alarms**                 | Detect unusual access patterns or quota issues                     | Minimal            | Low    |
| **Cross-region replication**          | Disaster recovery if primary region fails                          | ~100% storage cost | High   |

If you decide to implement any of these, update the Terraform code and this
README with the additional resources created.
