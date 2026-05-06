# ==============================================================================
# providers.tf -- Provider and Backend Configuration
#
# BOOTSTRAP ORDER (new AWS account, run once):
#
#   Step 1 -- Create state bucket and lock table first (backend is local):
#     terraform init
#     terraform apply -target=aws_s3_bucket.terraform_state \
#                     -target=aws_dynamodb_table.terraform_lock \
#                     -var-file=dev.tfvars
#
#   Step 2 -- Uncomment the backend "s3" block below, then re-init:
#     terraform init -reconfigure -var-file=dev.tfvars
#
#   Step 3 -- Full apply:
#     terraform apply -var-file=dev.tfvars
#
# RHCS Token:
#   Never hard-code the token. Set it as a GitHub Actions secret:
#     RHCS_TOKEN: ${{ secrets.RHCS_TOKEN }}
#   The rhcs provider reads it automatically from the RHCS_TOKEN env var.
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    rhcs = {
      source  = "terraform-redhat/rhcs"
      version = "~> 1.6"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  # Uncomment AFTER running Step 1 above.
  # Replace <ACCOUNT_ID> with your AWS account ID.
  #
  # backend "s3" {
  #   bucket         = "rosa-terraform-state-<ACCOUNT_ID>"
  #   key            = "rosa/terraform.tfstate"
  #   region         = "us-west-1"
  #   dynamodb_table = "rosa-terraform-lock"
  #   encrypt        = true
  # }
}

# AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = "MAS-ROSA"
        Environment = "dev"
        ManagedBy   = "Terraform"
        Cluster     = var.cluster_name
      },
      var.tags
    )
  }
}

# Red Hat Cloud Services Provider
# Token is read from the RHCS_TOKEN environment variable automatically.
# GitHub Actions: set RHCS_TOKEN as a repository secret.
# Local dev:      export RHCS_TOKEN=$(cat ~/.ocm-token)
provider "rhcs" {
  url = "https://api.openshift.com"
}
