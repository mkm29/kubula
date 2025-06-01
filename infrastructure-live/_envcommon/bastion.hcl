# Common Bastion configuration to be used across all environments

locals {
  # Load environment-specific variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  
  # Load decrypted secrets using sops
  secrets = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets/${local.environment_vars.locals.environment}/common.yaml")))
  
  # Extract commonly needed values
  environment = local.environment_vars.locals.environment
}

terraform {
  source = "${get_parent_terragrunt_dir()}/../terraform-modules/bastion"
}

dependency "vpc" {
  config_path = "../networking/vpc"
  
  mock_outputs = {
    vpc_id         = "vpc-mock"
    public_subnets = ["subnet-mock-1", "subnet-mock-2", "subnet-mock-3"]
  }
}

dependency "eks" {
  config_path = "../eks/cluster"
  
  mock_outputs = {
    node_security_group_id = "sg-mock"
  }
}

inputs = {
  name = "${local.environment}-bastion"
  
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.public_subnets
  
  instance_type = local.environment == "dev" ? "t3.micro" : "t3.small"
  
  # SSH key name from secrets
  key_name = local.secrets.bastion.ssh_key_name
  
  # Auto Scaling configuration
  desired_capacity = local.environment == "dev" ? 1 : 2
  min_size         = 1
  max_size         = local.environment == "dev" ? 2 : 3
  
  # Security configuration
  allowed_cidr_blocks     = local.secrets.bastion.allowed_cidrs
  allowed_security_groups = []
  
  # Allow bastion to SSH to EKS nodes
  egress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [dependency.vpc.outputs.vpc_cidr]
      description = "SSH to VPC instances"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS for package downloads and AWS APIs"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP for package downloads"
    }
  ]
  
  # Features
  enable_session_manager    = true
  enable_cloudwatch_logs    = true
  cloudwatch_logs_retention = local.environment == "dev" ? 7 : 30
  enable_eip                = true
  
  # Root volume configuration
  root_volume_size      = 20
  root_volume_type      = "gp3"
  root_volume_encrypted = true
  
  tags = {
    Name        = "${local.environment}-bastion"
    Environment = local.environment
  }
}