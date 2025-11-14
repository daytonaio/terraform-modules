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

  tags = {
    Environment = "production"
    Team        = "platform"
    ManagedBy   = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vpc_id | VPC ID where the runner will be deployed | string | - | yes |
| subnet_id | Subnet ID where the runner will be deployed | string | - | yes |
| ami_id | AMI ID for the EC2 instance | string | - | yes |
| daytona_api_url | Daytona API URL | string | - | yes |
| daytona_runner_token | Daytona runner authentication token | string | - | yes |
| name_prefix | Prefix for resource names | string | "daytona" | no |
| runner_version | Daytona runner version | string | "0.1.0" | no |
| instance_type | EC2 instance type | string | "t3.medium" | no |
| key_name | SSH key pair name | string | null | no |
| root_volume_type | Root volume type | string | "gp3" | no |
| root_volume_size | Root volume size in GB | number | 50 | no |
| poll_timeout | Job polling timeout | string | "30s" | no |
| poll_limit | Job polling limit | number | 10 | no |
| enable_ssh | Enable SSH access | bool | false | no |
| ssh_cidr_blocks | CIDR blocks for SSH access | list(string) | [] | no |
| enable_ssm | Enable SSM Session Manager | bool | true | no |
| tags | Additional tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | ID of the EC2 instance |
| instance_private_ip | Private IP address of the instance |
| instance_public_ip | Public IP address of the instance |
| security_group_id | ID of the security group |
| iam_role_arn | ARN of the IAM role |
| iam_role_name | Name of the IAM role |

## Security Considerations

1. **Runner Token**: The `daytona_runner_token` is marked as sensitive. Use Terraform variables or a secrets manager.
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
