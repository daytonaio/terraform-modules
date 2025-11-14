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
}

# EC2 instance for the runner
resource "aws_instance" "runner" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.runner.id]
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
      ami,
      user_data,
    ]
  }
}
