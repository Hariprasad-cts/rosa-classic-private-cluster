# ==============================================================================
# main.tf — Root Module
#
# Orchestrates 3 modules in the correct order:
#
#   +----------+    +----------+    +----------+
#   |  module  |    |  module  |    |  module  |
#   |   iam    |--->|   rosa   |<---|   dns    |
#   +----------+    +----------+    +----------+
#   IAM + OIDC      Cluster          Route53 zone
#
# VPC is pre-provisioned by the AWS team. This module reads the existing
# VPC and subnets via data sources — it does not create any networking.
#
# Additionally, two root-level resource files:
#   backend.tf      -- S3 + DynamoDB for remote state (bootstrap first)
#   prerequisites.tf -- preflight validation before cluster provisioning
# ==============================================================================

# This retrieves information about the AWS account that Terraform is currently running
data "aws_caller_identity" "current" {}

# Look up the pre-existing VPC to get its CIDR (used as ROSA machine_cidr)
data "aws_vpc" "existing" {
  id = var.vpc_id
}

# Module 1: IAM
# Creates: Installer/Support/ControlPlane/Worker IAM roles + policies +
#          instance profiles + OIDC provider (enables IRSA)
module "iam" {
  source = "./modules/iam"

  aws_region   = var.aws_region
  cluster_name = var.cluster_name
  tags         = var.tags
}

# Module 2: DNS
# Creates: Route53 public hosted zone for gilead.com (new account)
# After apply: add the output NS records to your domain registrar
module "dns" {
  source = "./modules/dns"

  cluster_name       = var.cluster_name
  base_domain        = var.base_domain
  create_hosted_zone = var.create_hosted_zone
  hosted_zone_id     = var.hosted_zone_id
  tags               = var.tags
}

# Module 3: ROSA Cluster
# Creates: ROSA Classic cluster (private, 5 workers), machine pool,
#          cluster-admin user
# This apply blocks for ~35-45 min on first run.
# Set GitHub Actions job timeout to >= 90 minutes.
module "rosa" {
  source = "./modules/rosa"

  cluster_name           = var.cluster_name
  aws_region             = var.aws_region
  openshift_version      = var.openshift_version
  availability_zones     = var.availability_zones
  private_subnet_ids       = var.private_subnet_ids
  vpc_cidr                 = data.aws_vpc.existing.cidr_block
  base_domain              = var.base_domain
  service_cidr             = var.service_cidr
  pod_cidr                 = var.pod_cidr
  host_prefix              = var.host_prefix
  machine_pool_name        = var.machine_pool_name
  worker_instance_type     = var.worker_instance_type
  worker_node_count        = var.worker_node_count
  worker_disk_size_gb      = var.worker_disk_size_gb
  installer_role_arn       = module.iam.installer_role_arn
  support_role_arn         = module.iam.support_role_arn
  control_plane_role_arn   = module.iam.control_plane_role_arn
  worker_role_arn          = module.iam.worker_role_arn
  oidc_endpoint_url        = module.iam.oidc_provider_url
  private                  = var.private
  aws_private_link         = var.aws_private_link
  multi_az                 = var.multi_az
  create_admin_user        = var.create_admin_user
  machine_pool_labels      = var.machine_pool_labels
  tags                     = var.tags

  depends_on = [
    module.iam,
    module.dns,
    null_resource.rosa_preflight_check,
    aws_dynamodb_table.terraform_lock,
  ]
}
