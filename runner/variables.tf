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

# Tags
variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
