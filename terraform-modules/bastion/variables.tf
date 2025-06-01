variable "name" {
  description = "Name to be used on all resources as identifier"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the bastion will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where the bastion instances will be deployed"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type for the bastion"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the EC2 key pair for SSH access"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the bastion instance. If not provided, uses latest Amazon Linux 2"
  type        = string
  default     = ""
}

variable "desired_capacity" {
  description = "Desired number of bastion instances"
  type        = number
  default     = 1
}

variable "min_size" {
  description = "Minimum number of bastion instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of bastion instances"
  type        = number
  default     = 2
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to SSH to the bastion"
  type        = list(string)
  default     = []
}

variable "allowed_security_groups" {
  description = "List of security group IDs allowed to SSH to the bastion"
  type        = list(string)
  default     = []
}

variable "egress_rules" {
  description = "List of egress rules for the bastion"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]
}

variable "enable_session_manager" {
  description = "Enable AWS Systems Manager Session Manager"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs for session logging"
  type        = bool
  default     = true
}

variable "cloudwatch_logs_retention" {
  description = "CloudWatch logs retention in days"
  type        = number
  default     = 30
}

variable "user_data" {
  description = "Additional user data script to run on bastion instances"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_eip" {
  description = "Enable Elastic IP for bastion instances"
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 8
}

variable "root_volume_type" {
  description = "Type of the root volume"
  type        = string
  default     = "gp3"
}

variable "root_volume_encrypted" {
  description = "Enable encryption for the root volume"
  type        = bool
  default     = true
}

variable "root_volume_kms_key_id" {
  description = "KMS key ID for root volume encryption"
  type        = string
  default     = ""
}