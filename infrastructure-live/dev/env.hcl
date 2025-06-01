# Dev environment configuration

locals {
  environment = "dev"
  
  # VPC configuration
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}