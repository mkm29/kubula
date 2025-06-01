# Dev EKS cluster configuration

include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/eks.hcl"
  expose = true
}

# Dev-specific overrides
inputs = {
  # Enable public endpoint for development
  cluster_endpoint_public_access = true
  
  # Dev-specific node group configuration
  node_groups = {
    general = {
      desired_size      = 2
      min_size          = 1
      max_size          = 4
      instance_types    = ["t3.medium", "t3a.medium"]
      capacity_type     = "SPOT"
      disk_size         = 50
      disk_type         = "gp3"
      disk_encrypted    = true
      disk_kms_key_id   = ""
      enable_monitoring = false
      labels = {
        workload = "general"
        Environment = "dev"
      }
      taints     = []
      subnet_ids = dependency.vpc.outputs.private_subnets
    }
  }
}