# Daytona Runner AWS Terraform Module

This Terraform module deploys a Daytona Runner on AWS EC2 with automated installation via cloud-init.

## Features

- **Automated Installation**: Uses cloud-init to download and install the Daytona runner .deb package
- **Configurable**: All runner settings can be customized via variables

## Prerequisites

- Terraform >= 1.0
- AWS credentials configured
- VPC and subnet already created
- Ubuntu 22.04 or later AMI
- Daytona runner .deb package hosted at an accessible URL

## Usage

### Basic Example

```hcl
module "daytona_runner" {
  source = "./packaging/terraform"

  # Network Configuration
  vpc_id    = "vpc-1234567890abcdef0"
  subnet_id = "subnet-1234567890abcdef0"

  # EC2 Configuration
  ami_id        = "ami-0c55b159cbfafe1f0"  # Ubuntu 22.04 LTS
  instance_type = "t3.medium"

  # Daytona Configuration
  daytona_api_url      = "https://api.daytona.example.com"
  daytona_runner_token = "your-runner-token-here"
  runner_version       = "0.1.0"

  # Optional: Enable SSM for secure access
  enable_ssm = true

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

### Advanced Example with Custom Configuration

```hcl
module "daytona_runner" {
  source = "./packaging/terraform"

  name_prefix = "production"

  # Network Configuration
  vpc_id    = "vpc-1234567890abcdef0"
  subnet_id = "subnet-1234567890abcdef0"

  # EC2 Configuration
  ami_id             = "ami-0c55b159cbfafe1f0"
  instance_type      = "t3.large"
  root_volume_size   = 100
  root_volume_type   = "gp3"

  # Daytona Configuration
  daytona_api_url      = "https://api.daytona.example.com"
  daytona_runner_token = var.runner_token  # Use variable for sensitive data
  runner_version       = "0.1.0"

  # Security Configuration
  enable_ssh       = true
  ssh_cidr_blocks  = ["10.0.0.0/8"]
  key_name         = "my-ssh-key"
  enable_ssm       = true

  # Additional IAM Policies
  additional_iam_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
    "arn:aws:iam::123456789012:policy/CustomPolicy"
  ]

  tags = {
    Environment = "production"
    Team        = "platform"
    ManagedBy   = "terraform"
  }
}
```

### Example with Existing Security Groups

```hcl
module "daytona_runner" {
  source = "./packaging/terraform"

  # Network Configuration
  vpc_id    = "vpc-1234567890abcdef0"
  subnet_id = "subnet-1234567890abcdef0"

  # EC2 Configuration
  ami_id        = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.medium"

  # Use existing security groups instead of creating a new one
  create_security_group = false
  security_group_ids    = [
    "sg-0123456789abcdef0",
    "sg-0fedcba9876543210"
  ]

  # Daytona Configuration
  daytona_api_url      = "https://api.daytona.example.com"
  daytona_runner_token = var.runner_token

  tags = {
    Environment = "production"
  }
}
```

### Example with Hybrid Security Groups

```hcl
# Create a module-managed security group but also attach additional ones
module "daytona_runner" {
  source = "./packaging/terraform"

  # Network Configuration
  vpc_id    = "vpc-1234567890abcdef0"
  subnet_id = "subnet-1234567890abcdef0"

  # EC2 Configuration
  ami_id        = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.medium"

  # Create default security group with SSH enabled
  create_security_group = true
  enable_ssh            = true
  ssh_cidr_blocks       = ["10.0.0.0/8"]

  # Also attach additional security groups
  security_group_ids = [
    "sg-0123456789abcdef0"  # Existing company-wide security group
  ]

  # Daytona Configuration
  daytona_api_url      = "https://api.daytona.example.com"
  daytona_runner_token = var.runner_token

  tags = {
    Environment = "production"
  }
}
```

### Example with Custom Cloud-Init Scripts

```hcl
# Add custom post-installation scripts
module "daytona_runner" {
  source = "./packaging/terraform"

  # Network Configuration
  vpc_id    = "vpc-1234567890abcdef0"
  subnet_id = "subnet-1234567890abcdef0"

  # EC2 Configuration
  ami_id        = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.medium"

  # Daytona Configuration
  api_url      = "https://api.daytona.example.com"
  runner_token = var.runner_token

  # Add custom scripts that run after Daytona installation
  additional_cloudinit_parts = [
    {
      filename     = "extra-setup.sh"
      content_type = "text/x-shellscript"
      content      = <<-EOF
        #!/bin/bash
        # Install additional tools
        apt-get install -y docker.io
        usermod -aG docker ubuntu
        
        # Configure monitoring
        echo "Setting up monitoring..."
        curl -sSO https://example.com/monitoring-agent.sh
        bash monitoring-agent.sh
      EOF
      merge_type   = null
    },
    {
      filename     = "custom-config.yaml"
      content_type = "text/cloud-config"
      content      = <<-EOF
        #cloud-config
        write_files:
          - path: /etc/custom-app/config.json
            permissions: '0644'
            content: |
              {
                "environment": "production",
                "features": ["docker", "monitoring"]
              }
      EOF
      merge_type   = null
    }
  ]

  tags = {
    Environment = "production"
  }
}
```

### Example with Inline Cloud-Init Script

```hcl
# Simpler example with a single post-installation script
module "daytona_runner" {
  source = "./packaging/terraform"

  vpc_id    = "vpc-1234567890abcdef0"
  subnet_id = "subnet-1234567890abcdef0"
  ami_id    = "ami-0c55b159cbfafe1f0"

  api_url      = "https://api.daytona.example.com"
  runner_token = var.runner_token

  # Run a simple script after installation
  additional_cloudinit_parts = [
    {
      filename     = "post-install.sh"
      content_type = "text/x-shellscript"
      content      = file("${path.module}/scripts/post-install.sh")
      merge_type   = null
    }
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vpc_id | VPC ID where the runner will be deployed | string | - | yes |
| subnet_id | Subnet ID where the runner will be deployed | string | - | yes |
| ami_id | AMI ID for the EC2 instance | string | - | yes |
| api_url | Daytona API URL | string | - | yes |
| runner_token | Daytona runner authentication token | string | - | yes |
| name_prefix | Prefix for resource names | string | "daytona" | no |
| runner_version | Daytona runner version | string | "0.1.0" | no |
| instance_type | EC2 instance type | string | "t3.medium" | no |
| key_name | SSH key pair name | string | null | no |
| root_volume_type | Root volume type | string | "gp3" | no |
| root_volume_size | Root volume size in GB | number | 50 | no |
| poll_timeout | Job polling timeout | string | "30s" | no |
| poll_limit | Job polling limit | number | 10 | no |
| create_security_group | Whether to create a new security group | bool | true | no |
| security_group_ids | List of security group IDs to attach (in addition to the created one if create_security_group is true) | list(string) | [] | no |
| enable_ssh | Enable SSH access (only when create_security_group is true) | bool | false | no |
| ssh_cidr_blocks | CIDR blocks for SSH access (only when create_security_group is true) | list(string) | [] | no |
| enable_ssm | Enable SSM Session Manager | bool | true | no |
| additional_iam_policy_arns | List of additional IAM policy ARNs to attach to the runner role | list(string) | [] | no |
| additional_cloudinit_parts | Additional cloud-init parts to run after the main Daytona installation | list(object) | [] | no |
| tags | Additional tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | ID of the EC2 instance |
| instance_private_ip | Private IP address of the instance |
| instance_public_ip | Public IP address of the instance |
| security_group_id | ID of the created security group (null if using existing security groups) |
| security_group_ids | List of all security group IDs attached to the instance |
| iam_role_arn | ARN of the IAM role |
| iam_role_name | Name of the IAM role |

## Cloud-Init Customization

The module uses cloud-init to bootstrap the Daytona runner installation. You can add custom cloud-init parts that run **after** the main Daytona installation completes.

### Content Types

- `text/x-shellscript` - Shell scripts (runs with `/bin/sh`)
- `text/cloud-config` - Cloud-config YAML (merged with existing config)
- `text/x-shellscript-per-boot` - Runs on every boot
- `text/x-shellscript-per-once` - Runs only on first boot
- `text/x-shellscript-per-instance` - Runs once per instance

### Merge Types

When using `text/cloud-config` content type, you can specify how it merges:
- `null` or omitted - Use cloud-init defaults
- `"list(append)"` - Append to lists
- `"dict(recurse_array)+list(append)"` - Deep merge with append
- `"dict(no_replace)"` - Only add new keys

### Best Practices

1. **Order matters**: Parts are executed in the order they're defined in the list
2. **Use shell scripts for simple tasks**: Easier to debug than complex cloud-config
3. **Check logs**: View cloud-init logs at `/var/log/cloud-init-output.log`
4. **Test thoroughly**: Cloud-init only runs once, so test your scripts carefully
5. **Keep it idempotent**: Scripts should be safe to run multiple times

## Security Considerations

1. **Runner Token**: The `runner_token` is marked as sensitive. Use Terraform variables or a secrets manager.
2. **SSH Access**: Disabled by default. Use SSM Session Manager instead for better security.
3. **Encryption**: Root volume is encrypted by default.
4. **IMDSv2**: Instance Metadata Service v2 is enforced.
5. **Network**: The instance only allows outbound traffic by default.

## Accessing the Instance

### Using SSM Session Manager (Recommended)

```bash
# No SSH key required
aws ssm start-session --target <instance-id>

# Check runner status
sudo systemctl status daytona-runner

# View logs
sudo journalctl -u daytona-runner -f
```

### Using SSH (If Enabled)

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<instance-ip>
```

## Troubleshooting

### Check cloud-init logs

```bash
# View cloud-init output
sudo cat /var/log/cloud-init-output.log

# Check cloud-init status
sudo cloud-init status
```

### Check runner status

```bash
# Service status
sudo systemctl status daytona-runner

# Service logs
sudo journalctl -u daytona-runner -n 100 --no-pager

# Check configuration
sudo cat /etc/daytona/runner.env
```

### Verify installation

```bash
# Check if binary exists
ls -la /opt/daytona/runner

# Check binary permissions
file /opt/daytona/runner
```

## License

Copyright 2025 Daytona Platforms Inc.
SPDX-License-Identifier: MIT
