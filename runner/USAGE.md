# Daytona Runner Module - Usage Guide

This guide explains how to use the Daytona Runner Terraform module with all available customization options.

## Quick Start

### Minimal Configuration

The simplest way to deploy a Daytona runner with default settings:

```hcl
module "daytona_runner" {
  source = "path/to/runner/module"

  # Required: Network Configuration
  vpc_id    = "vpc-0123456789abcdef0"
  subnet_id = "subnet-0123456789abcdef0"

  # Required: EC2 Configuration
  ami_id = "ami-0c55b159cbfafe1f0"  # Ubuntu 22.04 or later

  # Required: Daytona Configuration
  api_url      = "https://api.daytona.example.com"
  runner_token = var.runner_token  # Keep sensitive values in variables
}
```

This creates:
- ✅ EC2 instance with Daytona runner installed
- ✅ Security group allowing all outbound traffic
- ✅ IAM role with SSM Session Manager access
- ✅ Encrypted root volume

## Customization Options

### 1. Security Group Customization

#### Option A: Use the Default Security Group (Recommended for Quick Start)

```hcl
module "daytona_runner" {
  source = "path/to/runner/module"

  vpc_id    = "vpc-0123456789abcdef0"
  subnet_id = "subnet-0123456789abcdef0"
  ami_id    = "ami-0c55b159cbfafe1f0"

  api_url      = "https://api.daytona.example.com"
  runner_token = var.runner_token

  # Default security group with SSH enabled
  enable_ssh      = true
  ssh_cidr_blocks = ["10.0.0.0/8"]  # Your office/VPN CIDR
}
```

#### Option B: Use Only Your Existing Security Groups

```hcl
module "daytona_runner" {
  source = "path/to/runner/module"

  vpc_id    = "vpc-0123456789abcdef0"
  subnet_id = "subnet-0123456789abcdef0"
  ami_id    = "ami-0c55b159cbfafe1f0"

  api_url      = "https://api.daytona.example.com"
  runner_token = var.runner_token

  # Disable module's security group creation
  create_security_group = false

  # Use your own security groups
  security_group_ids = [
    "sg-0123456789abcdef0",  # Your existing SG
    "sg-0fedcba9876543210"   # Another SG if needed
  ]
}
```

#### Option C: Hybrid Approach (Module SG + Your SGs)

```hcl
module "daytona_runner" {
  source = "path/to/runner/module"

  vpc_id    = "vpc-0123456789abcdef0"
  subnet_id = "subnet-0123456789abcdef0"
  ami_id    = "ami-0c55b159cbfafe1f0"

  api_url      = "https://api.daytona.example.com"
  runner_token = var.runner_token

  # Create module's default security group
  create_security_group = true
  enable_ssh            = false  # No SSH in module's SG

  # ALSO attach your company security groups
  security_group_ids = [
    "sg-company-standard",     # Company baseline rules
    "sg-monitoring-access"     # Monitoring tools access
  ]
}
```

### 2. IAM Role Customization

The module creates an IAM role for the runner. You can attach additional policies:

#### Add AWS Managed Policies

```hcl
module "daytona_runner" {
  source = "path/to/runner/module"

  vpc_id    = "vpc-0123456789abcdef0"
  subnet_id = "subnet-0123456789abcdef0"
  ami_id    = "ami-0c55b159cbfafe1f0"

  api_url      = "https://api.daytona.example.com"
  runner_token = var.runner_token

  # Attach additional IAM policies
  additional_iam_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]
}
```

#### Add Your Custom Policies

```hcl
# First, create your custom policy
resource "aws_iam_policy" "runner_custom" {
  name        = "daytona-runner-custom-policy"
  description = "Custom policy for Daytona runner"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::my-build-artifacts/*"
      }
    ]
  })
}

# Then attach it to the runner
module "daytona_runner" {
  source = "path/to/runner/module"

  vpc_id    = "vpc-0123456789abcdef0"
  subnet_id = "subnet-0123456789abcdef0"
  ami_id    = "ami-0c55b159cbfafe1f0"

  api_url      = "https://api.daytona.example.com"
  runner_token = var.runner_token

  additional_iam_policy_arns = [
    aws_iam_policy.runner_custom.arn
  ]
}
```

### 3. Cloud-Init Customization

Add custom scripts that run **after** the Daytona runner installation completes.

#### Example: Install Docker

```hcl
module "daytona_runner" {
  source = "path/to/runner/module"

  vpc_id    = "vpc-0123456789abcdef0"
  subnet_id = "subnet-0123456789abcdef0"
  ami_id    = "ami-0c55b159cbfafe1f0"

  api_url      = "https://api.daytona.example.com"
  runner_token = var.runner_token

  # Install Docker after Daytona runner is set up
  additional_cloudinit_parts = [
    {
      filename     = "install-docker.sh"
      content_type = "text/x-shellscript"
      content      = <<-EOF
        #!/bin/bash
        set -e
        
        echo "Installing Docker..."
        apt-get update
        apt-get install -y docker.io
        
        # Add ubuntu user to docker group
        usermod -aG docker ubuntu
        
        # Enable and start Docker
        systemctl enable docker
        systemctl start docker
        
        echo "Docker installation completed"
      EOF
      merge_type   = null
    }
  ]
}
```

#### Example: Multiple Post-Installation Steps

```hcl
module "daytona_runner" {
  source = "path/to/runner/module"

  vpc_id    = "vpc-0123456789abcdef0"
  subnet_id = "subnet-0123456789abcdef0"
  ami_id    = "ami-0c55b159cbfafe1f0"

  api_url      = "https://api.daytona.example.com"
  runner_token = var.runner_token

  additional_cloudinit_parts = [
    # Step 1: Install development tools
    {
      filename     = "install-tools.sh"
      content_type = "text/x-shellscript"
      content      = <<-EOF
        #!/bin/bash
        apt-get update
        apt-get install -y \
          git \
          build-essential \
          python3-pip \
          nodejs \
          npm
      EOF
      merge_type   = null
    },
    
    # Step 2: Configure monitoring
    {
      filename     = "setup-monitoring.sh"
      content_type = "text/x-shellscript"
      content      = <<-EOF
        #!/bin/bash
        # Install CloudWatch agent
        wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
        dpkg -i amazon-cloudwatch-agent.deb
        
        # Configure and start the agent
        echo "Monitoring setup completed"
      EOF
      merge_type   = null
    },
    
    # Step 3: Write custom configuration files
    {
      filename     = "write-configs.yaml"
      content_type = "text/cloud-config"
      content      = <<-EOF
        #cloud-config
        write_files:
          - path: /etc/myapp/config.json
            permissions: '0644'
            content: |
              {
                "environment": "production",
                "region": "us-east-1",
                "features": {
                  "docker": true,
                  "monitoring": true
                }
              }
      EOF
      merge_type   = null
    }
  ]
}
```

#### Example: Use External Script Files

```hcl
module "daytona_runner" {
  source = "path/to/runner/module"

  vpc_id    = "vpc-0123456789abcdef0"
  subnet_id = "subnet-0123456789abcdef0"
  ami_id    = "ami-0c55b159cbfafe1f0"

  api_url      = "https://api.daytona.example.com"
  runner_token = var.runner_token

  # Reference external script files
  additional_cloudinit_parts = [
    {
      filename     = "post-install.sh"
      content_type = "text/x-shellscript"
      content      = file("${path.module}/scripts/post-install.sh")
      merge_type   = null
    },
    {
      filename     = "security-hardening.sh"
      content_type = "text/x-shellscript"
      content      = templatefile("${path.module}/scripts/hardening.sh.tpl", {
        environment = var.environment
        region      = var.aws_region
      })
      merge_type   = null
    }
  ]
}
```

## Complete Real-World Example

Here's a production-ready configuration combining all customization options:

```hcl
# variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID"
  type        = string
}

variable "daytona_api_url" {
  description = "Daytona API URL"
  type        = string
}

variable "daytona_runner_token" {
  description = "Daytona runner token"
  type        = string
  sensitive   = true
}

# main.tf
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# Custom IAM policy for S3 access
resource "aws_iam_policy" "runner_s3_access" {
  name        = "${var.environment}-daytona-runner-s3"
  description = "Allow runner to access build artifacts bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.environment}-build-artifacts",
          "arn:aws:s3:::${var.environment}-build-artifacts/*"
        ]
      }
    ]
  })
}

# Deploy Daytona Runner with full customization
module "daytona_runner" {
  source = "path/to/runner/module"

  name_prefix = var.environment

  # Network Configuration
  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id

  # EC2 Configuration
  ami_id           = data.aws_ami.ubuntu.id
  instance_type    = "t3.xlarge"
  root_volume_size = 100
  root_volume_type = "gp3"

  # Daytona Configuration
  api_url        = var.daytona_api_url
  runner_token   = var.daytona_runner_token
  runner_version = "0.1.0"
  poll_timeout   = "60s"
  poll_limit     = 20

  # Security: Use hybrid approach
  create_security_group = true
  enable_ssh            = false  # No SSH, use SSM only
  enable_ssm            = true

  # Also attach company standard security group
  security_group_ids = [
    aws_security_group.company_baseline.id
  ]

  # IAM: Attach additional policies
  additional_iam_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    aws_iam_policy.runner_s3_access.arn
  ]

  # Cloud-Init: Post-installation setup
  additional_cloudinit_parts = [
    # Install Docker and tools
    {
      filename     = "install-docker.sh"
      content_type = "text/x-shellscript"
      content      = <<-EOF
        #!/bin/bash
        set -e
        
        # Install Docker
        apt-get update
        apt-get install -y docker.io docker-compose
        
        # Configure Docker
        usermod -aG docker ubuntu
        systemctl enable docker
        
        # Install additional tools
        apt-get install -y git build-essential python3-pip
        
        echo "Post-installation completed"
      EOF
      merge_type   = null
    },
    
    # Set up monitoring
    {
      filename     = "setup-monitoring.sh"
      content_type = "text/x-shellscript"
      content      = file("${path.module}/scripts/setup-monitoring.sh")
      merge_type   = null
    },
    
    # Write application config
    {
      filename     = "app-config.yaml"
      content_type = "text/cloud-config"
      content      = <<-EOF
        #cloud-config
        write_files:
          - path: /etc/runner/config.json
            permissions: '0644'
            content: |
              {
                "environment": "${var.environment}",
                "features": ["docker", "ecr", "s3"]
              }
      EOF
      merge_type   = null
    }
  ]

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Team        = "platform"
  }
}

# Outputs
output "runner_instance_id" {
  description = "Runner EC2 instance ID"
  value       = module.daytona_runner.instance_id
}

output "runner_private_ip" {
  description = "Runner private IP"
  value       = module.daytona_runner.instance_private_ip
}

output "runner_iam_role_name" {
  description = "Runner IAM role name (for attaching more policies)"
  value       = module.daytona_runner.iam_role_name
}
```

## Cloud-Init Content Types Reference

| Content Type | Description | Use Case |
|--------------|-------------|----------|
| `text/x-shellscript` | Shell script executed once | General post-installation tasks |
| `text/cloud-config` | Cloud-config YAML format | Writing files, managing packages |
| `text/x-shellscript-per-boot` | Runs on every boot | Health checks, dynamic configuration |
| `text/x-shellscript-per-once` | Runs only on first boot | One-time setup tasks |
| `text/x-shellscript-per-instance` | Runs once per instance ID | Instance-specific initialization |

## Tips and Best Practices

### Security Groups
- **Default behavior is secure**: Only outbound traffic allowed
- **Use SSM instead of SSH**: Set `enable_ssm = true` and `enable_ssh = false`
- **Hybrid approach for complex environments**: Combine module SG with your existing ones

### IAM Policies
- **Principle of least privilege**: Only attach policies the runner actually needs
- **Use managed policies when possible**: AWS maintains them for security updates
- **Custom policies for specific access**: Create dedicated policies for your resources

### Cloud-Init Scripts
- **Keep scripts simple**: Each script should do one thing well
- **Test scripts locally first**: Debug on a test instance before adding to module
- **Check logs**: Use `/var/log/cloud-init-output.log` for troubleshooting
- **Make scripts idempotent**: Safe to run multiple times without side effects
- **Use external files for complex scripts**: Easier to maintain and test

### General
- **Use variables for sensitive data**: Never hardcode tokens or credentials
- **Tag everything**: Use the `tags` variable for cost tracking and organization
- **Start simple, then customize**: Begin with defaults, add customizations as needed
- **Version your runner**: Specify exact `runner_version` for reproducibility

## Accessing Your Runner

### Using SSM Session Manager (Recommended)

```bash
# Connect to the instance
aws ssm start-session --target <instance-id>

# Check Daytona runner status
sudo systemctl status daytona-runner

# View runner logs
sudo journalctl -u daytona-runner -f

# View cloud-init logs (for troubleshooting)
sudo cat /var/log/cloud-init-output.log
```

### Module Outputs

Access instance details from the module outputs:

```hcl
output "runner_instance_id" {
  value = module.daytona_runner.instance_id
}

output "runner_security_groups" {
  value = module.daytona_runner.security_group_ids
}

output "runner_iam_role" {
  value = module.daytona_runner.iam_role_name
}
```

## Troubleshooting

### Cloud-Init Not Running

```bash
# Check cloud-init status
cloud-init status

# View full output
sudo cat /var/log/cloud-init-output.log

# Re-run cloud-init (for testing only)
sudo cloud-init clean --logs
sudo cloud-init init
```

### Custom Scripts Failing

```bash
# Check which part failed
sudo cloud-init query -a

# View detailed logs
sudo journalctl -u cloud-init -n 100
```

### IAM Permission Issues

```bash
# Check which role is attached
aws ec2 describe-instances --instance-ids <instance-id> \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'

# Test IAM permissions from instance
aws sts get-caller-identity
```

## Need Help?

- Check the main [README.md](README.md) for detailed variable documentation
- Review the [example](example/main.tf) configuration
- View [cloud-init template](templates/cloud-init.yaml.tpl) to understand the base installation

