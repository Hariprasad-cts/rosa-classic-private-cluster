# ==============================================================================
# variables.tf -- Root Module Variable Declarations
#
# Values supplied via dev.tfvars (loaded explicitly in GitHub Actions):
#   terraform apply -var-file=dev.tfvars
#
# Sensitive values (admin_password, RHCS_TOKEN) come from GitHub Actions
# secrets -- never commit them to the repository.
# ==============================================================================

# Core

variable "aws_region" {
  description = "AWS region to deploy the ROSA cluster and supporting resources."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the ROSA Classic cluster. Used in resource names, tags, and DNS."
  type        = string
  default     = "mas-dev-rosa"
}

variable "openshift_version" {
  description = "OpenShift version for ROSA cluster."
  type        = string
  default     = "4.14.12"
}

# Networking

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must be at least /16 for ROSA."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Exactly 2 availability zones. Workers spread across both; single control-plane AZ."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly 2 availability zones are required."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the 2 private subnets -- one per AZ. ROSA workers/masters run here."
  type        = list(string)
  default     = ["10.0.0.0/22", "10.0.4.0/22"]
}

variable "public_subnet_cidr" {
  description = "CIDR block for the single public subnet. Hosts the NAT Gateway only."
  type        = string
  default     = "10.0.8.0/24"
}

# OpenShift Networking

variable "service_cidr" {
  description = "OpenShift service network CIDR. Must not overlap VPC, pod, or host OS ranges."
  type        = string
  default     = "172.30.0.0/16"
}

variable "pod_cidr" {
  description = "OpenShift pod network CIDR. Must not overlap VPC, service, or host OS ranges."
  type        = string
  default     = "10.128.0.0/14"
}

variable "host_prefix" {
  description = "Subnet prefix length per node for pod IPs (e.g. 23 gives each node a /23)."
  type        = number
  default     = 23
}

# Worker Nodes

variable "worker_instance_type" {
  description = "EC2 instance type for ROSA worker nodes. m5.xlarge is the ROSA minimum."
  type        = string
  default     = "m5.xlarge"
}

variable "worker_node_count" {
  description = "Number of worker nodes. 5 required for IBM Maximo Application Suite HA."
  type        = number
  default     = 5
}

variable "worker_disk_size_gb" {
  description = "Root disk size in GB for each worker node. MAS requires at least 300 GB."
  type        = number
  default     = 300
}

# DNS

variable "base_domain" {
  description = "Custom DNS domain for the ROSA cluster (e.g. gilead.com)."
  type        = string
  default     = "gilead.com"
}

variable "create_hosted_zone" {
  description = "true = create new Route53 zone. false = reuse existing zone (set hosted_zone_id)."
  type        = bool
  default     = true
}

variable "hosted_zone_id" {
  description = "Existing Route53 zone ID. Used only when create_hosted_zone = false."
  type        = string
  default     = ""
}

# Cluster Provisioning

variable "machine_pool_name" {
  description = "Name of the additional machine pool for worker nodes."
  type        = string
  default     = "worker-pool"
}

variable "idp_name" {
  description = "Name of the HTPasswd identity provider created in the cluster."
  type        = string
  default     = "cluster-admin-idp"
}

# Cluster Admin

variable "admin_username" {
  description = "HTPasswd IDP username for the cluster-admin account."
  type        = string
  default     = "cluster-admin"
}

variable "admin_password" {
  description = "Password for cluster-admin. Leave null to auto-generate."
  type        = string
  sensitive   = true
  default     = null
}

# Tags

variable "tags" {
  description = "Additional tags applied to all taggable resources."
  type        = map(string)
  default     = {}
}
