# Copyright (c) 2025 Daytona
# Licensed under the MIT License - see LICENSE file for details

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "example"
      ManagedBy   = "terraform"
      Project     = "daytona-runner-example"
    }
  }
}

# Get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Query the latest Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create VPC using the official AWS VPC module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "daytona-runner-vpc"
  cidr = "10.0.0.0/16"

  azs             = [data.aws_availability_zones.available.names[0]]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Deploy Daytona Runner
module "daytona_runner" {
  source = "../."

  # Network Configuration - use the VPC we created
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.private_subnets[0]

  # EC2 Configuration - use the Ubuntu AMI we queried
  ami_id        = data.aws_ami.ubuntu.id
  instance_type = "m7i.2xlarge"

  # Daytona Runner Configuration
  api_url        = "https://daytona.example.com/api"
  runner_token   = "YOUR_RUNNER_TOKEN_HERE"
  runner_version = "0.1.0"
  poll_timeout   = "30s"
  poll_limit     = 10

  # Security Configuration
  enable_ssm = true
  enable_ssh = false

  # Optional: Use existing security groups instead of creating a new one
  # create_security_group = false
  # security_group_ids    = ["sg-0123456789abcdef0"]

  # Optional: Attach additional security groups alongside the created one
  # security_group_ids = ["sg-0123456789abcdef0"]

  # Optional: Attach additional IAM policies to the runner role
  # additional_iam_policy_arns = [
  #   "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
  #   "arn:aws:iam::123456789012:policy/CustomPolicy"
  # ]

  # Optional: Add custom cloud-init scripts that run after Daytona installation
  # additional_cloudinit_parts = [
  #   {
  #     filename     = "post-install.sh"
  #     content_type = "text/x-shellscript"
  #     content      = <<-EOF
  #       #!/bin/bash
  #       echo "Running custom post-installation script"
  #       apt-get install -y docker.io
  #       systemctl enable docker
  #     EOF
  #     merge_type   = null
  #   }
  # ]

  tags = {
    Example = true
  }
}
