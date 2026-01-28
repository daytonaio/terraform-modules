
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

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "example"
      ManagedBy   = "terraform"
      Project     = "daytona"
    }
  }
}

// Get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

// Query the Daytona runner AMI
data "aws_ami" "daytona_runner" {
  most_recent = true
  owners      = ["967657494466"]

  filter {
    name   = "name"
    values = ["daytona-runner-docker-ubuntu-24.04-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

// Create VPC using the official AWS VPC module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "daytona-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
}

// Register Daytona region
module "daytona_region" {
  source = "../../region"

  daytona_api_url = var.daytona_api_url
  daytona_api_key = var.daytona_api_key
  name            = var.region_name

  // Optional proxy, SSH gateway, and snapshot manager configuration
  proxy_url            = var.proxy_url
  ssh_gateway_url      = var.ssh_gateway_url
  snapshot_manager_url = var.snapshot_manager_url

  // VPC configuration for ECS services (required if proxy, SSH gateway, or snapshot manager is enabled)
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnets
  private_subnet_ids = module.vpc.private_subnets
}

// Deploy Daytona Runner
module "daytona_runner" {
  source = "../../runner"

  // Network Configuration
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.private_subnets[0]

  // EC2 Configuration
  ami_id        = data.aws_ami.daytona_runner.id
  instance_type = var.runner_instance_type

  // Daytona Runner Configuration
  api_url   = var.daytona_api_url
  api_key   = var.daytona_api_key
  region_id = module.daytona_region.id

  // Security Configuration
  enable_ssm = true
  enable_ssh = false

  // Allow proxy and SSH gateway ECS tasks to reach runner on port 8080
  ingress_security_group_ids = merge(
    var.proxy_url != null ? { "proxy" = module.daytona_region.proxy_ecs_security_group_id } : {},
    var.ssh_gateway_url != null ? { "ssh-gateway" = module.daytona_region.ssh_gateway_ecs_security_group_id } : {},
  )

  tags = {
    DaytonaRegionName = var.region_name
  }
}
