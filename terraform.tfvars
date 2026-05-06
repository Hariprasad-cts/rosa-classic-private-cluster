# -------------------------------------------------------
# ROSA Classic - Terraform Variable Values
# MAS Dev Environment
# -------------------------------------------------------

aws_region   = "us-east-1"
cluster_name = "mas-dev-rosa"

# VPC
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.0.0.0/22", "10.0.4.0/22", "10.0.8.0/22"]
private_subnet_cidrs = ["10.0.12.0/22", "10.0.16.0/22", "10.0.20.0/22"]

# Worker Nodes (MAS requirements)
worker_instance_type = "m5.4xlarge"   # 16 vCPU, 64GB RAM
worker_node_count    = 3              # Minimum for MAS HA
worker_disk_size_gb  = 300            # MAS needs large disk

# OpenShift
openshift_version  = "4.14.12"
account_role_prefix = "MAS-ROSA"

# VPC Endpoints
enable_s3_endpoint  = true
enable_sts_endpoint = true
enable_ec2_endpoint = true

# -------------------------------------------------------
# DNS Configuration - Forward ROSA URLs to gilead.com
# -------------------------------------------------------
gilead_domain     = "gilead.com"
mas_subdomain     = "mas"           # → mas.gilead.com
api_subdomain     = "rosa-api"      # → rosa-api.gilead.com
console_subdomain = "rosa-console"  # → rosa-console.gilead.com

# Fill in after cluster is created:
# rosa describe cluster -c mas-dev-rosa | grep "DNS"
rosa_base_domain = ""   # e.g. abc123.p1.openshiftapps.com
