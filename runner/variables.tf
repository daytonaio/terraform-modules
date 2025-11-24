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

variable "runner_token" {
  description = "Daytona runner authentication token"
  type        = string
  sensitive   = true
}

variable "runner_version" {
  description = "Daytona runner version"
  type        = string
  default     = "0.1.0"
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
variable "security_group_ids" {
  description = "List of security group IDs to attach to the instance. If empty, a new security group will be created."
  type        = list(string)
  default     = []
}

variable "create_security_group" {
  description = "Whether to create a new security group. If false, you must provide security_group_ids."
  type        = bool
  default     = true
}

variable "enable_ssh" {
  description = "Enable SSH access to the instance (only used when create_security_group is true)"
  type        = bool
  default     = false
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access (only used when create_security_group is true)"
  type        = list(string)
  default     = []
}

variable "enable_ssm" {
  description = "Enable AWS Systems Manager Session Manager access"
  type        = bool
  default     = true
}

variable "additional_iam_policy_arns" {
  description = "List of additional IAM policy ARNs to attach to the runner role"
  type        = list(string)
  default     = []
}

# Cloud-init Configuration
variable "additional_cloudinit_parts" {
  description = "Additional cloud-init parts to run after the main Daytona runner installation"
  type = list(object({
    filename     = string
    content_type = string
    content      = string
    merge_type   = optional(string)
  }))
  default = []
}

# Tags
variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
