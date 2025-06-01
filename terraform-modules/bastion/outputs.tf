output "security_group_id" {
  description = "Security group ID of the bastion host"
  value       = aws_security_group.bastion.id
}

output "iam_role_arn" {
  description = "IAM role ARN of the bastion host"
  value       = aws_iam_role.bastion.arn
}

output "iam_instance_profile_arn" {
  description = "IAM instance profile ARN of the bastion host"
  value       = aws_iam_instance_profile.bastion.arn
}

output "autoscaling_group_id" {
  description = "The autoscaling group id"
  value       = aws_autoscaling_group.bastion.id
}

output "autoscaling_group_name" {
  description = "The autoscaling group name"
  value       = aws_autoscaling_group.bastion.name
}

output "launch_template_id" {
  description = "The ID of the launch template"
  value       = aws_launch_template.bastion.id
}

output "launch_template_latest_version" {
  description = "The latest version of the launch template"
  value       = aws_launch_template.bastion.latest_version
}

output "elastic_ip_addresses" {
  description = "Elastic IP addresses allocated for bastion hosts"
  value       = aws_eip.bastion[*].public_ip
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for bastion logs"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.bastion[0].name : ""
}