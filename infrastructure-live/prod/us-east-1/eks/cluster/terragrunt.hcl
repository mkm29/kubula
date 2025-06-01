# Prod EKS cluster configuration

include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/eks.hcl"
  expose = true
}

# Prod-specific overrides
inputs = {
  # Disable public endpoint for production
  cluster_endpoint_public_access = false
  
  # Prod-specific node group configuration
  node_groups = {
    general = {
      desired_size      = 3
      min_size          = 2
      max_size          = 10
      instance_types    = ["m5.large", "m5a.large"]
      capacity_type     = "ON_DEMAND"
      disk_size         = 100
      disk_type         = "gp3"
      disk_encrypted    = true
      disk_kms_key_id   = ""
      enable_monitoring = true
      labels = {
        workload = "general"
        Environment = "prod"
      }
      taints     = []
      subnet_ids = dependency.vpc.outputs.private_subnets
    }
    
    critical = {
      desired_size      = 2
      min_size          = 2
      max_size          = 6
      instance_types    = ["m5.xlarge", "m5a.xlarge"]
      capacity_type     = "ON_DEMAND"
      disk_size         = 150
      disk_type         = "gp3"
      disk_encrypted    = true
      disk_kms_key_id   = ""
      enable_monitoring = true
      labels = {
        workload = "critical"
        Environment = "prod"
      }
      taints = [
        {
          key    = "workload"
          value  = "critical"
          effect = "NO_SCHEDULE"
        }
      ]
      subnet_ids = dependency.vpc.outputs.private_subnets
    }
  }
}