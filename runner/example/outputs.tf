# Copyright (c) 2025 Daytona
# Licensed under the MIT License - see LICENSE file for details

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = module.vpc.private_subnets[0]
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.vpc.public_subnets[0]
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = module.vpc.natgw_ids[0]
}

output "instance_id" {
  description = "ID of the EC2 instance running the Daytona runner"
  value       = module.daytona_runner.instance_id
}

output "instance_private_ip" {
  description = "Private IP address of the runner instance"
  value       = module.daytona_runner.instance_private_ip
}

output "instance_public_ip" {
  description = "Public IP address of the runner instance (if assigned)"
  value       = module.daytona_runner.instance_public_ip
}

output "security_group_id" {
  description = "ID of the security group"
  value       = module.daytona_runner.security_group_id
}

output "iam_role_arn" {
  description = "ARN of the IAM role"
  value       = module.daytona_runner.iam_role_arn
}

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = module.daytona_runner.iam_role_name
}

output "ubuntu_ami_id" {
  description = "ID of the Ubuntu 24.04 AMI used"
  value       = data.aws_ami.ubuntu.id
}

output "ubuntu_ami_name" {
  description = "Name of the Ubuntu 24.04 AMI used"
  value       = data.aws_ami.ubuntu.name
}

output "ssm_connect_command" {
  description = "Command to connect to the instance via SSM Session Manager"
  value       = "aws ssm start-session --target ${module.daytona_runner.instance_id}"
}
