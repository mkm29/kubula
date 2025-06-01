# Common EKS configuration to be used across all environments

locals {
  # Load environment-specific variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  
  # Load decrypted secrets using sops
  secrets = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets/${local.environment_vars.locals.environment}/common.yaml")))
  
  # Extract commonly needed values
  environment = local.environment_vars.locals.environment
  region      = local.region_vars.locals.aws_region
  
  # Common node group configuration
  node_group_defaults = {
    disk_size         = 100
    disk_type         = "gp3"
    disk_encrypted    = true
    disk_kms_key_id   = ""
    enable_monitoring = true
    capacity_type     = local.environment == "dev" ? "SPOT" : "ON_DEMAND"
  }
}

terraform {
  source = "${get_parent_terragrunt_dir()}/../terraform-modules/eks"
}

dependency "vpc" {
  config_path = "../networking/vpc"
  
  mock_outputs = {
    vpc_id          = "vpc-mock"
    private_subnets = ["subnet-mock-1", "subnet-mock-2", "subnet-mock-3"]
  }
}

inputs = {
  cluster_name    = "${local.environment}-eks-cluster"
  cluster_version = "1.28"
  
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnets
  
  enable_irsa = true
  
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
  
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = local.environment == "dev" ? true : false
  
  cluster_endpoint_public_access_cidrs = local.environment == "dev" ? ["0.0.0.0/0"] : []
  cluster_endpoint_private_access_cidrs = local.secrets.eks.cluster_endpoint_private_access_cidrs
  
  enable_cluster_encryption = true
  
  node_groups = {
    general = merge(
      local.node_group_defaults,
      {
        desired_size   = local.environment == "dev" ? 2 : 3
        min_size       = local.environment == "dev" ? 1 : 2
        max_size       = local.environment == "dev" ? 4 : 10
        instance_types = local.environment == "dev" ? ["t3.medium", "t3a.medium"] : ["m5.large", "m5a.large"]
        labels = {
          workload = "general"
        }
        taints     = []
        subnet_ids = dependency.vpc.outputs.private_subnets
      }
    )
  }
  
  # IAM mappings
  manage_aws_auth_configmap = true
  aws_auth_roles = []
  aws_auth_users = []
  
  # EKS Add-ons
  cluster_addons = {
    vpc-cni = {
      addon_version            = "v1.15.4-eksbuild.1"
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = ""
    }
    kube-proxy = {
      addon_version            = "v1.28.4-eksbuild.1"
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = ""
    }
    coredns = {
      addon_version            = "v1.10.1-eksbuild.6"
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = ""
    }
    aws-ebs-csi-driver = {
      addon_version            = "v1.25.0-eksbuild.1"
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = ""
    }
  }
  
  tags = {
    Name        = "${local.environment}-eks-cluster"
    Environment = local.environment
  }
}