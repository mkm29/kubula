# Terragrunt EKS Infrastructure

This project provides a production-ready Terragrunt configuration for deploying AWS EKS clusters with proper network isolation, bastion hosts, and secrets management using SOPS.

## Architecture Overview

- **VPC**: Multi-AZ VPC with private subnets for EKS worker nodes and public subnets (DMZ) for bastion hosts
- **EKS**: Managed Kubernetes cluster with worker nodes in private subnets
- **Bastion**: Auto-scaled bastion hosts in public subnets for secure SSH access
- **Security**: SOPS integration for secrets management, VPC endpoints for private communication
- **High Availability**: Multi-AZ deployment with separate NAT gateways per AZ (in production)

## Project Structure

```
.
├── terraform-modules/          # Reusable Terraform modules
│   ├── vpc/                    # VPC with public/private subnets
│   ├── eks/                    # EKS cluster and node groups
│   ├── bastion/                # Bastion host with auto-scaling
│   └── iam/                    # IAM roles and policies
│
├── infrastructure-live/        # Terragrunt configurations
│   ├── terragrunt.hcl          # Root configuration
│   ├── _envcommon/             # Common configurations
│   │   ├── vpc.hcl             # Shared VPC config
│   │   ├── eks.hcl             # Shared EKS config
│   │   └── bastion.hcl         # Shared Bastion config
│   ├── dev/                    # Development environment
│   │   ├── account.hcl         # Dev AWS account config
│   │   ├── env.hcl             # Dev environment variables
│   │   └── us-east-1/          # Dev us-east-1 region
│   └── prod/                   # Production environment
│       ├── account.hcl         # Prod AWS account config
│       ├── env.hcl             # Prod environment variables
│       └── us-east-1/          # Prod us-east-1 region
│
├── secrets/                   # SOPS-encrypted secrets
│   ├── dev/                   # Dev secrets
│   └── prod/                  # Prod secrets
│
└── .sops.yaml                 # SOPS configuration
```

## Prerequisites

1. **AWS CLI** configured with appropriate profiles
2. **Terraform** >= 1.11
3. or **OpenTofu** >= 1.9.1
4. **Terragrunt** >= 0.80.4
5. **SOPS** >= 3.10.0
6. **kubectl** (for interacting with EKS)
7. **AWS KMS keys** for SOPS encryption

## Initial Setup

### 1. Configure AWS Accounts

Update the account configuration files with your AWS account IDs:

```bash
# infrastructure-live/dev/account.hcl
locals {
  account_name   = "dev"
  aws_account_id = "YOUR_DEV_ACCOUNT_ID"
  aws_profile    = "dev"
}

# infrastructure-live/prod/account.hcl
locals {
  account_name   = "prod"
  aws_account_id = "YOUR_PROD_ACCOUNT_ID"
  aws_profile    = "prod"
}
```

### 2. Create KMS Keys for SOPS

Create KMS keys in each AWS account for SOPS encryption:

```bash
# Dev account
aws kms create-alias --alias-name alias/kubula-dev --target-key-id $(aws kms create-key --description "SOPS key for dev" --query 'KeyMetadata.KeyId' --output text) --profile dev

# Prod account
aws kms create-alias --alias-name alias/kubula-prod --target-key-id $(aws kms create-key --description "SOPS key for prod" --query 'KeyMetadata.KeyId' --output text) --profile prod
```

### 3. Update SOPS Configuration

The `.sops.yaml` file is already configured to use KMS aliases. Ensure the AWS account IDs match yours.

### 4. Encrypt Secrets

Edit and encrypt the secrets files:

```bash
# Edit dev secrets
sops secrets/dev/common.yaml

# Edit prod secrets
sops secrets/prod/common.yaml
```

Required secrets:
- `bastion.ssh_key_name`: EC2 key pair name for SSH access
- `bastion.allowed_cidrs`: CIDR blocks allowed to SSH to bastion
- `eks.cluster_endpoint_private_access_cidrs`: CIDR blocks for private API access

## Deployment Guide

### Deploy Development Environment

```bash
cd infrastructure-live/dev/us-east-1

# Deploy VPC first
cd networking/vpc
terragrunt apply

# Deploy EKS cluster
cd ../../eks/cluster
terragrunt apply

# Deploy Bastion host
cd ../../bastion
terragrunt apply
```

### Deploy Production Environment

```bash
cd infrastructure-live/prod/us-east-1

# Follow the same order as dev
```

### Deploy All at Once

Terragrunt can handle dependencies and deploy in the correct order:

```bash
cd infrastructure-live/dev/us-east-1
terragrunt run-all apply
```

## Accessing the Cluster

### 1. Update kubeconfig

```bash
aws eks update-kubeconfig --name dev-eks-cluster --region us-east-1 --profile dev
```

### 2. SSH to Bastion

```bash
# Get bastion IP
BASTION_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=dev-bastion" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --profile dev)

# SSH to bastion
ssh -i ~/.ssh/your-key.pem ec2-user@$BASTION_IP
```

### 3. Access Nodes via Bastion

From the bastion, you can SSH to any node in the private subnets.

## Security Best Practices

1. **Network Isolation**: Worker nodes are in private subnets with no direct internet access
2. **Bastion Access**: Limited to specific CIDR blocks defined in secrets
3. **API Endpoint**: Production cluster has private-only API endpoint
4. **Secrets Management**: All sensitive data encrypted with SOPS
5. **IAM Roles**: Least privilege principle with IRSA support
6. **VPC Endpoints**: Private communication with AWS services
7. **Flow Logs**: VPC flow logs enabled for security monitoring

## Customization

### Adding Node Groups

Edit the `node_groups` configuration in the environment-specific EKS terragrunt.hcl:

```hcl
node_groups = {
  gpu = {
    desired_size   = 2
    min_size       = 1
    max_size       = 4
    instance_types = ["g4dn.xlarge"]
    # ... other configurations
  }
}
```

### Modifying Network CIDR

Update the VPC CIDR in the environment's `env.hcl`:

```hcl
vpc_cidr = "10.200.0.0/16"
```

### Adding VPC Endpoints

Add endpoints to the VPC configuration:

```hcl
vpc_endpoints = [
  "s3",
  "ec2",
  "elasticloadbalancing",
  # ... add more as needed
]
```

## Troubleshooting

### Cannot Access Cluster API

1. Check security group rules
2. Verify private access CIDRs in secrets
3. Ensure VPN/bastion connectivity

### Nodes Not Joining Cluster

1. Check IAM roles and policies
2. Verify VPC endpoints are created
3. Review node user data logs

### SOPS Decryption Fails

1. Verify KMS key permissions
2. Check AWS profile configuration
3. Ensure SOPS is using correct KMS key

## Maintenance

### Updating EKS Version

1. Update `cluster_version` in eks module
2. Update addon versions to compatible versions
3. Apply changes with `terragrunt apply`
4. Update node groups if needed

### Rotating Secrets

```bash
# Decrypt, edit, and re-encrypt
sops secrets/dev/common.yaml
```

## Cost Optimization

- Dev environment uses SPOT instances and single NAT gateway
- Production uses ON_DEMAND instances and multi-AZ NAT gateways
- VPC endpoints reduce NAT gateway costs
- Auto-scaling configured for all components

## Clean Up

To destroy the infrastructure:

```bash
cd infrastructure-live/dev/us-east-1
terragrunt run-all destroy
```

**Note**: Destroy in reverse order if doing manually (bastion → eks → vpc)