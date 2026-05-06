# ==============================================================================
# main.tf — Root Module
#
# Orchestrates 4 modules in the correct order:
#
#   +----------+    +----------+    +----------+    +----------+
#   |  module  |    |  module  |    |  module  |    |  module  |
#   |   vpc    |--->|   iam    |--->|   rosa   |<---|   dns    |
#   +----------+    +----------+    +----------+    +----------+
#   Networking      IAM + OIDC      Cluster          Route53 zone
#
# Additionally, two root-level resource files:
#   backend.tf      -- S3 + DynamoDB for remote state (bootstrap first)
#   prerequisites.tf -- preflight validation before cluster provisioning
# ==============================================================================

data "aws_caller_identity" "current" {}

# Module 1: VPC
# Creates: VPC, 2 private subnets, 1 public subnet, IGW, NAT GW,
#          route tables, VPC endpoints (S3/EC2/STS/ELB/ECR x2)
module "vpc" {
  source = "./modules/vpc"

  cluster_name         = var.cluster_name
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidr   = var.public_subnet_cidr
  tags                 = var.tags
}

# Module 2: IAM
# Creates: Installer/Support/ControlPlane/Worker IAM roles + policies +
#          instance profiles + OIDC provider (enables IRSA)
module "iam" {
  source = "./modules/iam"

  aws_region   = var.aws_region
  cluster_name = var.cluster_name
  tags         = var.tags
}

# Module 3: DNS
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

# Module 4: ROSA Cluster
# Creates: ROSA Classic cluster (private, 5 workers), machine pool,
#          HTPasswd IDP, cluster-admin user
# This apply blocks for ~35-45 min on first run.
# Set GitHub Actions job timeout to >= 90 minutes.
module "rosa" {
  source = "./modules/rosa"

  cluster_name           = var.cluster_name
  aws_region             = var.aws_region
  openshift_version      = var.openshift_version
  availability_zones     = var.availability_zones
  private_subnet_ids     = module.vpc.private_subnet_ids
  vpc_cidr               = var.vpc_cidr
  base_domain            = var.base_domain
  service_cidr           = var.service_cidr
  pod_cidr               = var.pod_cidr
  host_prefix            = var.host_prefix
  machine_pool_name      = var.machine_pool_name
  idp_name               = var.idp_name
  worker_instance_type   = var.worker_instance_type
  worker_node_count      = var.worker_node_count
  worker_disk_size_gb    = var.worker_disk_size_gb
  admin_username         = var.admin_username
  admin_password         = var.admin_password
  installer_role_arn     = module.iam.installer_role_arn
  support_role_arn       = module.iam.support_role_arn
  control_plane_role_arn = module.iam.control_plane_role_arn
  worker_role_arn        = module.iam.worker_role_arn
  oidc_endpoint_url      = module.iam.oidc_provider_url
  tags                   = var.tags

  depends_on = [
    module.vpc,
    module.iam,
    module.dns,
    null_resource.rosa_preflight_check,
    aws_dynamodb_table.terraform_lock,
  ]
}
