# ROSA Classic Terraform - MAS Dev Environment

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Terraform | >= 1.5.0 | https://developer.hashicorp.com/terraform/install |
| AWS CLI | >= 2.x | https://aws.amazon.com/cli/ |
| ROSA CLI | latest | https://mirror.openshift.com/pub/openshift-v4/clients/rosa/latest/ |

---

## Step 1 — Configure AWS CLI

```bash
aws configure
# Enter your AWS Access Key, Secret Key, region: us-east-1
```

Verify:
```bash
aws sts get-caller-identity
```

---

## Step 2 — Get Red Hat OCM Token

1. Go to: https://console.redhat.com/openshift/token
2. Log in with your Red Hat account
3. Copy the token
4. Add it to terraform.tfvars:

```hcl
rhcs_token = "eyJhbGciOi..."
```

---

## Step 3 — Enable ROSA in AWS Account

```bash
# Install ROSA CLI
rosa login --token=<your-red-hat-token>

# Enable ROSA service (one-time per account)
rosa init

# Verify
rosa verify quota
rosa verify permissions
```

---

## Step 4 — Deploy (in order)

```bash
# Initialize providers
terraform init

# Preview changes
terraform plan -var-file=terraform.tfvars

# Step 4a: Deploy VPC first
terraform apply -target=module.vpc -var-file=terraform.tfvars -auto-approve

# Step 4b: Deploy IAM roles
terraform apply -target=module.iam -var-file=terraform.tfvars -auto-approve

# Step 4c: Deploy ROSA cluster (takes ~40 mins)
terraform apply -var-file=terraform.tfvars -auto-approve
```

---

## Step 5 — Get Cluster Credentials

```bash
# Get admin password
terraform output -raw admin_password

# Get console URL
terraform output cluster_console_url

# Login via ROSA CLI
rosa describe cluster -c mas-dev-rosa

# Login via oc CLI
oc login <cluster_api_url> --username mas-admin --password <admin_password>
```

---

## Step 6 — Verify Cluster for MAS

```bash
# Check all nodes are ready
oc get nodes

# Check cluster operators
oc get co

# Check storage class (gp3 needed for MAS)
oc get storageclass
```

---

## Destroy (when needed)

```bash
terraform destroy -var-file=terraform.tfvars
```

---

## Architecture Summary

```
Internet
    |
Internet Gateway (mas-dev-igw)
    |
+---+------------------------------------------+
|   VPC: 10.0.0.0/16  (mas-dev-vpc)           |
|                                               |
|  Public Subnets (NAT Gateways only)          |
|  +-----------+ +-----------+ +-----------+   |
|  | 10.0.0/22 | | 10.0.4/22 | | 10.0.8/22 |  |
|  | NAT GW-1  | | NAT GW-2  | | NAT GW-3  |  |
|  +-----------+ +-----------+ +-----------+   |
|       |               |             |         |
|  Private Subnets (ROSA Worker Nodes)         |
|  +------------+ +------------+ +----------+  |
|  | 10.0.12/22 | | 10.0.16/22 | |10.0.20/22|  |
|  | Workers AZ1| | Workers AZ2| |Workers AZ3|  |
|  +------------+ +------------+ +----------+  |
|                                               |
|  VPC Endpoints: S3, STS, EC2                 |
+-----------------------------------------------+
```

---

## MAS Node Requirements Met

| Requirement | Value |
|------------|-------|
| Instance type | m5.4xlarge (16 vCPU / 64GB) |
| Node count | 3 (HA across 3 AZs) |
| Disk size | 300 GB |
| OCP version | 4.14.12 (MAS certified) |
| Storage class | gp3 |
| Multi-AZ | Yes |
