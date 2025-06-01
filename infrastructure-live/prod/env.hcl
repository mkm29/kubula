# Prod environment configuration

locals {
  environment = "prod"
  
  # VPC configuration
  vpc_cidr           = "10.100.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}