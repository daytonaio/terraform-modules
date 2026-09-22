// Copyright (c) 2025 Daytona
// Licensed under the MIT License - see LICENSE file for details

variable "daytona_api_url" {
  type        = string
  description = "Daytona API URL"
}

variable "daytona_api_key" {
  type        = string
  description = "Daytona API key"
  sensitive   = true
}

variable "name" {
  type        = string
  description = "Name of the region"
}

variable "proxy_url" {
  type        = string
  description = "Proxy URL for the region (setting this enables proxy deployment), e.g., https://proxy.example.com:8080"
  default     = null
}

variable "ssh_gateway_url" {
  type        = string
  description = "SSH Gateway URL for the region (setting this enables SSH Gateway deployment), e.g., ssh-gateway.example.com:2222"
  default     = null
}

variable "snapshot_manager_url" {
  type        = string
  description = "Snapshot Manager URL for the region, e.g., https://snapshot-manager.example.com. Required: the snapshot registry is infrastructure this deployment depends on, not an optional feature."
  nullable    = false

  validation {
    condition     = can(regex("^(https?)://([^:/]+):?([0-9]*)$", var.snapshot_manager_url))
    error_message = "snapshot_manager_url is required for this BYOC deployment; configure the snapshot registry endpoint, e.g., https://snapshot-manager.example.com."
  }
}

// VPC Configuration for ECS
variable "vpc_id" {
  type        = string
  description = "VPC ID for ECS deployment (required if proxy or SSH gateway is enabled)"
  default     = null
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for load balancers"
  default     = []
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for ECS tasks"
  default     = []
}

// Proxy Configuration
variable "internal" {
  type        = bool
  description = "Use internal load balancers (private, not internet-facing)"
  default     = false
}

variable "proxy_image" {
  type        = string
  description = "Docker image for the proxy"
  default     = "daytonaio/daytona-proxy:v0.125.0-rc.4-441e56b7"
}

variable "proxy_cpu" {
  type        = number
  description = "CPU units for proxy task"
  default     = 256
}

variable "proxy_memory" {
  type        = number
  description = "Memory (MB) for proxy task"
  default     = 512
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS"
  default     = null
}

// SSH Gateway Configuration

variable "ssh_gateway_image" {
  type        = string
  description = "Docker image for the SSH Gateway"
  default     = "daytonaio/ssh-gateway:latest"
}

variable "ssh_gateway_cpu" {
  type        = number
  description = "CPU units for SSH Gateway task"
  default     = 256
}

variable "ssh_gateway_memory" {
  type        = number
  description = "Memory (MB) for SSH Gateway task"
  default     = 512
}

// Snapshot Manager Configuration

variable "snapshot_manager_image" {
  type        = string
  description = "Docker image for the Snapshot Manager"
  default     = "daytonaio/daytona-snapshot-manager:v0.125.0-rc.4-441e56b"
}

variable "snapshot_manager_cpu" {
  type        = number
  description = "CPU units for Snapshot Manager task"
  default     = 256
}

variable "snapshot_manager_memory" {
  type        = number
  description = "Memory (MB) for Snapshot Manager task"
  default     = 512
}

variable "additional_snapshot_manager_ecs_security_group_ids" {
  type        = list(string)
  description = "Additional security group IDs to attach to Snapshot Manager ECS tasks"
  default     = []
}

variable "additional_alb_security_group_ids" {
  type        = list(string)
  description = "Additional security group IDs to attach to the ALB"
  default     = []
}

variable "additional_nlb_security_group_ids" {
  type        = list(string)
  description = "Additional security group IDs to attach to the NLB"
  default     = []
}

variable "additional_ecs_security_group_ids" {
  type        = list(string)
  description = "Additional security group IDs to attach to ECS tasks"
  default     = []
}

variable "additional_ssh_gateway_ecs_security_group_ids" {
  type        = list(string)
  description = "Additional security group IDs to attach to SSH Gateway ECS tasks"
  default     = []
}

variable "additional_task_policy_arns" {
  type        = list(string)
  description = "Additional IAM policy ARNs to attach to the ECS task role"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Additional tags for resources"
  default     = {}
}
