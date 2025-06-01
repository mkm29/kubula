# Dev Bastion configuration

include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/bastion.hcl"
  expose = true
}

# Dev-specific overrides
inputs = {
  # Single bastion instance for dev
  desired_capacity = 1
  
  # Smaller instance for dev
  instance_type = "t3.micro"
}