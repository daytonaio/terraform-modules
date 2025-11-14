# Copyright (c) 2025 Daytona
# Licensed under the MIT License - see LICENSE file for details

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.runner.id
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.runner.private_ip
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance (if assigned)"
  value       = aws_instance.runner.public_ip
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.runner.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.runner.arn
}

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.runner.name
}
