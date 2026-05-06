# ==============================================================================
# backend.tf — Remote State Resources
#
# Creates the S3 bucket and DynamoDB table Terraform uses as its backend.
#
# Why S3 + DynamoDB?
#   S3 stores terraform.tfstate — shared across all GitHub Actions runs.
#   DynamoDB provides state locking — prevents concurrent apply corruption.
#
# Bootstrap sequence (new AWS account — run once):
#   Step 1: terraform apply -target=aws_s3_bucket.terraform_state \
#                           -target=aws_dynamodb_table.terraform_lock \
#                           -var-file=dev.tfvars
#   Step 2: Uncomment backend "s3" in providers.tf, then run:
#           terraform init -reconfigure -var-file=dev.tfvars
#   Step 3: Full apply — terraform apply -var-file=dev.tfvars
# ==============================================================================

locals {
  state_bucket_name = "rosa-terraform-state-${data.aws_caller_identity.current.account_id}"
}

# S3 bucket — stores the terraform.tfstate file
resource "aws_s3_bucket" "terraform_state" {
  bucket = local.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = local.state_bucket_name
    Purpose = "Terraform remote state"
  }
}

# Versioning — every state change creates a new version (rollback capability)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption at rest — AES-256 SSE-S3
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access — state files must never be publicly readable
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB lock table — prevents concurrent terraform apply corruption
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "rosa-terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name    = "rosa-terraform-lock"
    Purpose = "Terraform state locking"
  }
}
