# Prod Bastion configuration

include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/bastion.hcl"
  expose = true
}

# Prod-specific overrides
inputs = {
  # Multiple bastion instances for high availability
  desired_capacity = 2
  min_size         = 2
  max_size         = 3
  
  # Larger instance for prod
  instance_type = "t3.small"
  
  # Longer log retention for prod
  cloudwatch_logs_retention = 90
}