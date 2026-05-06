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
  service_cidr       = "172.30.0.0/16"
  pod_cidr           = "10.128.0.0/14"
  host_prefix        = 23

  private          = true
  aws_private_link = true

  base_domain = var.base_domain
  multi_az    = false

  compute_machine_type = var.worker_instance_type
  replicas             = var.worker_node_count

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
  timeout = 60
}

# Machine pool -- 5 x m5.xlarge workers for MAS
resource "rhcs_machine_pool" "workers" {
  cluster            = rhcs_cluster_rosa_classic.this.id
  name               = "mas-worker-pool"
  machine_type       = var.worker_instance_type
  replicas           = var.worker_node_count
  availability_zones = var.availability_zones
  disk_size          = var.worker_disk_size_gb

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
  name    = "cluster-admin-idp"
  type    = "htpasswd"

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
