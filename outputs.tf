# ==============================================================================
# outputs.tf -- Root Module Outputs
#
# Run after apply:
#   terraform output
#   terraform output -raw admin_password   (for sensitive values)
# ==============================================================================

# VPC (pre-provisioned by AWS team — outputs reflect what was passed in)

output "vpc_id" {
  description = "VPC ID used by the ROSA cluster."
  value       = var.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs where ROSA master and worker nodes run."
  value       = var.private_subnet_ids
}

# IAM

output "installer_role_arn" {
  description = "Installer IAM Role ARN"
  value       = module.iam.installer_role_arn
}

output "support_role_arn" {
  description = "Support IAM Role ARN"
  value       = module.iam.support_role_arn
}

output "control_plane_role_arn" {
  description = "ControlPlane IAM Role ARN"
  value       = module.iam.control_plane_role_arn
}

output "worker_role_arn" {
  description = "Worker IAM Role ARN"
  value       = module.iam.worker_role_arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL -- enables IRSA for cluster operators."
  value       = module.iam.oidc_provider_url
}

# ROSA Cluster

output "cluster_id" {
  description = "ROSA Cluster ID (Red Hat OCM resource ID)"
  value       = module.rosa.cluster_id
}

output "cluster_api_url" {
  description = "Cluster API URL -- requires VPN or Direct Connect (private cluster)."
  value       = module.rosa.cluster_api_url
}

output "cluster_console_url" {
  description = "OpenShift Console URL -- requires VPN or Direct Connect (private cluster)."
  value       = module.rosa.cluster_console_url
}

output "admin_username" {
  description = "Cluster-admin HTPasswd username."
  value       = module.rosa.admin_username
}

output "admin_password" {
  description = "Cluster-admin password. Retrieve with: terraform output -raw admin_password"
  value       = module.rosa.admin_password
  sensitive   = true
}

# DNS

output "route53_zone_id" {
  description = "Route53 hosted zone ID for base_domain."
  value       = module.dns.zone_id
}

output "route53_ns_records" {
  description = "NS records to add at your domain registrar after first apply."
  value       = module.dns.ns_records
}
