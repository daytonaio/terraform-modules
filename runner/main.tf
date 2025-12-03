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

# Security group for the runner instance
resource "aws_security_group" "runner" {
  count = var.create_security_group ? 1 : 0

  name_prefix = "${var.name_prefix}-runner-"
  description = "Security group for Daytona Runner"
  vpc_id      = var.vpc_id

  # Egress - allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  # Optional SSH access
  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_cidr_blocks
      description = "SSH access"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-runner-sg"
    }
  )
}

locals {
  # Use provided security groups or the created one
  security_group_ids = var.create_security_group ? concat([aws_security_group.runner[0].id], var.security_group_ids) : var.security_group_ids
}

# IAM role for the EC2 instance
resource "aws_iam_role" "runner" {
  name_prefix = "${var.name_prefix}-runner-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-runner-role"
    }
  )
}

# Attach SSM policy for session manager access
resource "aws_iam_role_policy_attachment" "runner_ssm" {
  count      = var.enable_ssm ? 1 : 0
  role       = aws_iam_role.runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach additional IAM policies
resource "aws_iam_role_policy_attachment" "runner_additional" {
  count      = length(var.additional_iam_policy_arns)
  role       = aws_iam_role.runner.name
  policy_arn = var.additional_iam_policy_arns[count.index]
}

# IAM instance profile
resource "aws_iam_instance_profile" "runner" {
  name_prefix = "${var.name_prefix}-runner-"
  role        = aws_iam_role.runner.name

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-runner-profile"
    }
  )
}

# Cloud-init configuration
data "cloudinit_config" "runner" {
  gzip          = true
  base64_encode = true

  # Main Daytona runner installation part (runs first)
  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
      daytona_api_url      = var.api_url
      daytona_runner_token = var.runner_token
      runner_version       = var.runner_version
      poll_timeout         = var.poll_timeout
      poll_limit           = var.poll_limit
    })
  }

  # Additional cloud-init parts (run after the main installation)
  dynamic "part" {
    for_each = var.additional_cloudinit_parts
    content {
      filename     = part.value.filename
      content_type = part.value.content_type
      content      = part.value.content
      merge_type   = part.value.merge_type
    }
  }
}

# EC2 instance for the runner
resource "aws_instance" "runner" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = local.security_group_ids
  iam_instance_profile   = aws_iam_instance_profile.runner.name
  key_name               = var.key_name

  user_data = data.cloudinit_config.runner.rendered

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-runner"
    }
  )

  lifecycle {
    ignore_changes = [
      user_data,
    ]
  }
}
