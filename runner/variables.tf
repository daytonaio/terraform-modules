# Copyright (c) 2025 Daytona
# Licensed under the MIT License - see LICENSE file for details

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "daytona"
}

# Network Configuration
variable "vpc_id" {
  description = "VPC ID where the runner will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the runner will be deployed"
  type        = string
}

# EC2 Configuration
variable "ami_id" {
  description = "AMI ID for the EC2 instance (Ubuntu 22.04 or later recommended)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "SSH key pair name (optional)"
  type        = string
  default     = null
}

variable "root_volume_type" {
  description = "Root volume type"
  type        = string
  default     = "gp3"
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 50
}

# Daytona Configuration
variable "api_url" {
  description = "Daytona API URL"
  type        = string
}

variable "api_key" {
  description = "Daytona API key"
  type        = string
  sensitive   = true
}

variable "region_id" {
  description = "Daytona region ID"
  type        = string
}

variable "runner_name" {
  description = "Name for the runner (used in API registration)"
  type        = string
  default     = null
}

# Runner Configuration (optional)
variable "poll_timeout" {
  description = "Job polling timeout"
  type        = string
  default     = "30s"
}

variable "poll_limit" {
  description = "Job polling limit"
  type        = number
  default     = 10
}

# Security Configuration
variable "enable_ssh" {
  description = "Enable SSH access to the instance"
  type        = bool
  default     = false
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = []
}

variable "enable_ssm" {
  description = "Enable AWS Systems Manager Session Manager access"
  type        = bool
  default     = true
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs to attach to the runner instance"
  type        = list(string)
  default     = []
}

variable "ingress_security_group_ids" {
  description = "Map of security group IDs allowed to access the runner on port 8080 (for proxy/SSH gateway ECS tasks). Keys are static identifiers, values are security group IDs."
  type        = map(string)
  default     = {}
}

variable "additional_iam_policy_arns" {
  description = "Additional IAM policy ARNs to attach to the runner role"
  type        = list(string)
  default     = []
}

variable "custom_iam_policy" {
  description = "Custom IAM policy document (JSON) to attach to the runner role"
  type        = string
  default     = null
}

# Customization
variable "user_data_append" {
  description = "Additional user data script to run after base initialization (shell script)"
  type        = string
  default     = null
}

# Tags
variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
