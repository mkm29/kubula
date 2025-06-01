# Dev VPC configuration

include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/vpc.hcl"
  expose = true
}

# Dev-specific overrides can be added here
inputs = {
  # Any dev-specific VPC configurations
}