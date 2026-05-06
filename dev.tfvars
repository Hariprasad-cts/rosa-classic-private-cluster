# ==============================================================================
# dev.tfvars — Development Environment Variable Values
#
# Loaded explicitly (NOT auto-loaded by Terraform):
#   terraform plan  -var-file=dev.tfvars
#   terraform apply -var-file=dev.tfvars
#
# GitHub Actions usage:
#   - Non-sensitive values live here (committed to repo)
#   - Sensitive values come from GitHub Actions secrets:
#       TF_VAR_admin_password: ${{ secrets.ROSA_ADMIN_PASSWORD }}
#       RHCS_TOKEN:            ${{ secrets.RHCS_TOKEN }}
#
# Do NOT put rhcs_token or admin_password in this file.
# ==============================================================================

# ── Core ──────────────────────────────────────────────────────────────────────
aws_region        = "us-east-1"
cluster_name      = "mas-dev-rosa"
openshift_version = "4.14.12"

# ── Networking ────────────────────────────────────────────────────────────────
vpc_cidr = "10.0.0.0/16"

# Exactly 2 AZs (multi_az = false, but workers span both private subnets)
availability_zones = ["us-east-1a", "us-east-1b"]

# 2 private subnets — one per AZ — ROSA masters and workers run here
private_subnet_cidrs = ["10.0.0.0/22", "10.0.4.0/22"]

# 1 public subnet — NAT Gateway only, no workloads
public_subnet_cidr = "10.0.8.0/24"

# ── OpenShift Networking ──────────────────────────────────────────────────────
service_cidr = "172.30.0.0/16"
pod_cidr     = "10.128.0.0/14"
host_prefix  = 23

# ── Worker Nodes ──────────────────────────────────────────────────────────────
worker_instance_type = "m5.xlarge"  # 4 vCPU / 16 GB RAM — ROSA minimum
worker_node_count    = 5            # MAS Application Suite requires 5 workers for HA
worker_disk_size_gb  = 300          # MAS requires 300 GB per worker node

# ── Cluster Provisioning ──────────────────────────────────────────────────────
cluster_wait_timeout = 60
machine_pool_name    = "worker-pool"
idp_name             = "cluster-admin-idp"

# ── DNS ───────────────────────────────────────────────────────────────────────
base_domain        = "gilead.com"
create_hosted_zone = true   # true = new Route53 zone created for gilead.com
hosted_zone_id     = ""     # Leave empty when create_hosted_zone = true

# After first apply, run:
#   terraform output route53_ns_records
# Then add those 4 NS records at your domain registrar for gilead.com.

# ── Cluster Admin ─────────────────────────────────────────────────────────────
admin_username = "cluster-admin"
# admin_password is NOT set here — comes from GitHub Actions secret TF_VAR_admin_password
# If running locally and admin_password is null, a secure random password is auto-generated.

# ── Tags ──────────────────────────────────────────────────────────────────────
tags = {
  CostCenter  = "engineering"
  Owner       = "platform-team"
  Environment = "dev"
}
