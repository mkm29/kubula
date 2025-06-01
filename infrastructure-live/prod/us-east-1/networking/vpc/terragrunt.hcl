# Prod VPC configuration

include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/vpc.hcl"
  expose = true
}

# Prod-specific overrides
inputs = {
  # Multi-NAT gateway for high availability
  single_nat_gateway = false
}