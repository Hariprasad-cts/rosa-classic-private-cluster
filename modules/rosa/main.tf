# ==============================================================================
# modules/rosa/main.tf
#
# Creates the ROSA Classic private cluster and associated resources:
#
#   rhcs_cluster_rosa_classic  -- the cluster itself (~40 min first apply)
#   rhcs_cluster_wait          -- blocks until state = ready
#   rhcs_machine_pool          -- 5 worker nodes (m5.xlarge)
#   random_password            -- auto-generated admin password
#   rhcs_identity_provider     -- HTPasswd IDP (initial access)
#   rhcs_group_membership      -- admin user -> cluster-admins group
#
# Settings:
#   private = true          -- API + Ingress NLBs are internal only
#   aws_private_link = true -- Red Hat SRE access via AWS PrivateLink
#   multi_az = false        -- 2-AZ workers, single control-plane zone
#   sts mode = "auto"       -- OIDC/IRSA, no long-lived IAM keys
#
# Custom domain (gilead.com):
#   The Route53 hosted zone is created by the dns module.
#   The base domain is registered in your Red Hat OCM account separately.
#   After cluster creation, ROSA auto-creates DNS records in the zone:
#     api.<cluster>.<base_domain>        -- internal API NLB
#     *.apps.<cluster>.<base_domain>     -- internal Ingress NLB
# ==============================================================================

data "aws_caller_identity" "current" {}

resource "rhcs_cluster_rosa_classic" "this" {
  name           = var.cluster_name
  cloud_region   = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id
  version        = var.openshift_version

  availability_zones = var.availability_zones
  aws_subnet_ids     = var.private_subnet_ids
  machine_cidr       = var.vpc_cidr
  service_cidr       = var.service_cidr
  pod_cidr           = var.pod_cidr
  host_prefix        = var.host_prefix

  # Private cluster: API + Ingress NLBs are internal only
  # Access requires VPN or AWS Direct Connect into the VPC
  private          = true
  aws_private_link = true

  # 2-AZ workers, single control-plane zone
  multi_az = false

  # Workers: 5 x m5.xlarge (masters are always 3, managed by Red Hat)
  compute_machine_type = var.worker_instance_type
  replicas             = var.worker_node_count

  # STS mode: OIDC/IRSA -- no long-lived IAM keys stored anywhere
  sts = {
    mode                 = "auto"
    managed_policies     = true
    operator_role_prefix = var.cluster_name
    role_arn             = var.installer_role_arn
    support_role_arn     = var.support_role_arn

    instance_iam_roles = {
      master_role_arn = var.control_plane_role_arn
      worker_role_arn = var.worker_role_arn
    }

    oidc_endpoint_url = var.oidc_endpoint_url
  }

  properties = {
    rosa_creator_arn = data.aws_caller_identity.current.arn
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [version]
  }
}

# Wait until cluster reaches "ready" state (~35-45 min)
# Set GitHub Actions job timeout to >= 90 minutes
resource "rhcs_cluster_wait" "this" {
  cluster = rhcs_cluster_rosa_classic.this.id
  timeout = var.cluster_wait_timeout
}

# Machine pool -- 5 x m5.xlarge workers for MAS
resource "rhcs_machine_pool" "workers" {
  cluster            = rhcs_cluster_rosa_classic.this.id
  name         = var.machine_pool_name
  machine_type = var.worker_instance_type
  replicas     = var.worker_node_count
  disk_size    = var.worker_disk_size_gb

  labels = {
    "node-role.kubernetes.io/worker" = ""
    "mas-workload"                   = "true"
  }

  depends_on = [rhcs_cluster_wait.this]
}

# Auto-generated admin password (used if admin_password variable is null)
resource "random_password" "admin" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"
}

# HTPasswd Identity Provider -- initial admin access
# For production: replace with SSO or LDAP IDP
resource "rhcs_identity_provider" "htpasswd" {
  cluster = rhcs_cluster_rosa_classic.this.id
  name = var.idp_name

  htpasswd = {
    users = [{
      username = var.admin_username
      password = var.admin_password != null ? var.admin_password : random_password.admin.result
    }]
  }

  depends_on = [rhcs_cluster_wait.this]
}

# Add admin user to cluster-admins group
resource "rhcs_group_membership" "admin" {
  cluster    = rhcs_cluster_rosa_classic.this.id
  group      = "cluster-admins"
  user       = var.admin_username
  depends_on = [rhcs_identity_provider.htpasswd]
}
