# Common VPC configuration to be used across all environments

locals {
  # Load environment-specific variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  
  # Extract commonly needed values
  environment = local.environment_vars.locals.environment
  vpc_cidr    = local.environment_vars.locals.vpc_cidr
  azs         = local.environment_vars.locals.availability_zones
  
  # Calculate subnet CIDRs
  # We'll create 3 private subnets and 3 public subnets across 3 AZs
  # Example for 10.0.0.0/16:
  # Private: 10.0.0.0/20, 10.0.16.0/20, 10.0.32.0/20 (4096 IPs each)
  # Public:  10.0.128.0/24, 10.0.129.0/24, 10.0.130.0/24 (256 IPs each)
  
  cidr_block = local.vpc_cidr
  newbits_private = 4  # /16 + 4 = /20
  newbits_public  = 8  # /16 + 8 = /24
  
  private_subnet_cidrs = [for i in range(length(local.azs)) : cidrsubnet(local.cidr_block, local.newbits_private, i)]
  public_subnet_cidrs  = [for i in range(length(local.azs)) : cidrsubnet(local.cidr_block, local.newbits_public, i + 128)]
}

terraform {
  source = "${get_parent_terragrunt_dir()}/../terraform-modules/vpc"
}

inputs = {
  name = "${local.environment}-vpc"
  
  vpc_cidr = local.vpc_cidr
  
  availability_zones   = local.azs
  private_subnet_cidrs = local.private_subnet_cidrs
  public_subnet_cidrs  = local.public_subnet_cidrs
  
  enable_nat_gateway = true
  single_nat_gateway = local.environment == "dev" ? true : false
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  # VPC endpoints for EKS
  vpc_endpoints = [
    "s3",
    "ec2",
    "ecr.api",
    "ecr.dkr",
    "sts",
    "logs",
    "ssm",
    "ssmmessages",
    "ec2messages"
  ]
  
  enable_flow_logs      = true
  flow_logs_destination = "s3"
  
  tags = {
    Name        = "${local.environment}-vpc"
    Environment = local.environment
  }
}