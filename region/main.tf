// Copyright (c) 2025 Daytona
// Licensed under the MIT License - see LICENSE file for details

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    terracurl = {
      source  = "devops-rob/terracurl"
      version = "~> 2.0"
    }
  }
}

// Register region via Daytona API
resource "terracurl_request" "region" {
  name   = "daytona-region-${var.name}"
  url    = "${var.daytona_api_url}/regions"
  method = "POST"

  headers = {
    Content-Type  = "application/json"
    Authorization = "Bearer ${var.daytona_api_key}"
  }

  request_body = jsonencode({
    name          = var.name
    proxyUrl      = var.proxy_url
    sshGatewayUrl = var.ssh_gateway_url
  })

  response_codes = [200, 201]

  lifecycle {
    ignore_changes = [headers, request_body]
  }
}

locals {
  region_response     = jsondecode(terracurl_request.region.response)
  proxy_api_key       = var.proxy_url != null ? local.region_response.proxyApiKey : null
  ssh_gateway_api_key = var.ssh_gateway_url != null ? local.region_response.sshGatewayApiKey : null

  // Parse proxy URL: https://proxy.example.com:8080 -> protocol, domain, port
  proxy_url_regex      = var.proxy_url != null ? regex("^(https?)://([^:/]+):?([0-9]*)$", var.proxy_url) : null
  proxy_protocol       = local.proxy_url_regex != null ? local.proxy_url_regex[0] : null
  proxy_domain         = local.proxy_url_regex != null ? local.proxy_url_regex[1] : null
  proxy_port           = local.proxy_url_regex != null ? (local.proxy_url_regex[2] != "" ? tonumber(local.proxy_url_regex[2]) : (local.proxy_protocol == "https" ? 443 : 80)) : null
  proxy_container_port = 8080 // Unprivileged port for container
  deploy_proxy         = var.proxy_url != null

  // Parse SSH gateway URL: ssh-gateway.example.com:22 -> domain, port
  ssh_gateway_url_regex      = var.ssh_gateway_url != null ? regex("^([^:/]+):?([0-9]*)$", var.ssh_gateway_url) : null
  ssh_gateway_domain         = local.ssh_gateway_url_regex != null ? local.ssh_gateway_url_regex[0] : null
  ssh_gateway_port           = local.ssh_gateway_url_regex != null ? (local.ssh_gateway_url_regex[1] != "" ? tonumber(local.ssh_gateway_url_regex[1]) : 22) : null
  ssh_gateway_container_port = 2222 // Unprivileged port for container
  deploy_ssh_gateway         = var.ssh_gateway_url != null

  // Parse snapshot manager URL: https://snapshot-manager.example.com:8080 -> protocol, domain, port
  snapshot_manager_url_regex      = var.snapshot_manager_url != null ? regex("^(https?)://([^:/]+):?([0-9]*)$", var.snapshot_manager_url) : null
  snapshot_manager_protocol       = local.snapshot_manager_url_regex != null ? local.snapshot_manager_url_regex[0] : null
  snapshot_manager_domain         = local.snapshot_manager_url_regex != null ? local.snapshot_manager_url_regex[1] : null
  snapshot_manager_port           = local.snapshot_manager_url_regex != null ? (local.snapshot_manager_url_regex[2] != "" ? tonumber(local.snapshot_manager_url_regex[2]) : (local.snapshot_manager_protocol == "https" ? 443 : 80)) : null
  snapshot_manager_container_port = 5000
  deploy_snapshot_manager         = true

  deploy_ecs = local.deploy_proxy || local.deploy_ssh_gateway || local.deploy_snapshot_manager
}

// Data sources
data "aws_region" "current" {}

data "aws_vpc" "selected" {
  count = local.deploy_ssh_gateway || local.deploy_snapshot_manager ? 1 : 0
  id    = var.vpc_id
}

data "aws_caller_identity" "current" {}

// Shared ECS Cluster for proxy and SSH gateway
resource "aws_ecs_cluster" "main" {
  count = local.deploy_ecs ? 1 : 0
  name  = "daytona-${var.name}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags, {
    Name = "daytona-${var.name}"
  })
}
