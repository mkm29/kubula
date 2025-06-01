# Root terragrunt configuration

locals {
  # Parse the file path to extract environment and region
  path_parts = compact(split("/", path_relative_to_include()))
  environment = length(local.path_parts) >= 1 ? local.path_parts[0] : ""
  region      = length(local.path_parts) >= 2 ? local.path_parts[1] : ""
  
  # Load account-wide variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl", "account.hcl"), { locals = {} })
  
  # Load region-wide variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl", "region.hcl"), { locals = {} })
  
  # Extract the variables we need
  account_name = local.account_vars.locals.account_name
  account_id   = local.account_vars.locals.aws_account_id
  aws_region   = local.region_vars.locals.aws_region
}

# Generate AWS provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"

  # Only these AWS Account IDs may be operated on
  allowed_account_ids = ["${local.account_id}"]

  default_tags {
    tags = {
      Environment = "${local.environment}"
      Region      = "${local.aws_region}"
      ManagedBy   = "Terragrunt"
    }
  }
}

# Additional providers needed for EKS
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}
EOF
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = "terragrunt-state-${local.account_name}-${local.account_id}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = "terragrunt-locks-${local.account_name}"
    
    s3_bucket_tags = {
      Name        = "Terragrunt State Storage"
      Environment = local.environment
      ManagedBy   = "Terragrunt"
    }
    
    dynamodb_table_tags = {
      Name        = "Terragrunt Lock Table"
      Environment = local.environment
      ManagedBy   = "Terragrunt"
    }
  }
  
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Configure root level variables that all modules can inherit
inputs = {
  environment  = local.environment
  region       = local.aws_region
  account_name = local.account_name
  account_id   = local.account_id
}