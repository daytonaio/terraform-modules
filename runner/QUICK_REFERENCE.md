# Daytona Runner Module - Quick Reference

Quick copy-paste examples for common use cases.

## 🚀 Basic Setup

```hcl
module "daytona_runner" {
  source = "path/to/runner/module"
  
  vpc_id    = "vpc-xxxxx"
  subnet_id = "subnet-xxxxx"
  ami_id    = "ami-xxxxx"
  
  api_url      = "https://api.daytona.example.com"
  runner_token = var.runner_token
}
```

## 🔒 Security Group Options

### Use Default Module SG
```hcl
# No additional config needed - this is default behavior
```

### Use Your Existing SG Only
```hcl
create_security_group = false
security_group_ids    = ["sg-xxxxx"]
```

### Use Both (Module + Your SG)
```hcl
create_security_group = true
security_group_ids    = ["sg-xxxxx"]
```

### Enable SSH in Module SG
```hcl
enable_ssh      = true
ssh_cidr_blocks = ["10.0.0.0/8"]
```

## 🔑 IAM Policy Options

### Add AWS Managed Policies
```hcl
additional_iam_policy_arns = [
  "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
  "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
]
```

### Add Your Custom Policy
```hcl
resource "aws_iam_policy" "custom" {
  name   = "my-custom-policy"
  policy = jsonencode({...})
}

module "daytona_runner" {
  # ... other config ...
  additional_iam_policy_arns = [
    aws_iam_policy.custom.arn
  ]
}
```

## 📝 Cloud-Init Options

### Install Docker
```hcl
additional_cloudinit_parts = [
  {
    filename     = "docker.sh"
    content_type = "text/x-shellscript"
    content      = <<-EOF
      #!/bin/bash
      apt-get update
      apt-get install -y docker.io
      usermod -aG docker ubuntu
    EOF
    merge_type   = null
  }
]
```

### Multiple Scripts
```hcl
additional_cloudinit_parts = [
  {
    filename     = "install-tools.sh"
    content_type = "text/x-shellscript"
    content      = "#!/bin/bash\napt-get install -y git"
    merge_type   = null
  },
  {
    filename     = "setup-monitoring.sh"
    content_type = "text/x-shellscript"
    content      = file("${path.module}/scripts/monitoring.sh")
    merge_type   = null
  }
]
```

### Write Config Files
```hcl
additional_cloudinit_parts = [
  {
    filename     = "config.yaml"
    content_type = "text/cloud-config"
    content      = <<-EOF
      #cloud-config
      write_files:
        - path: /etc/app/config.json
          content: |
            {"env": "prod"}
    EOF
    merge_type   = null
  }
]
```

## 🎯 Common Combinations

### Production Setup
```hcl
module "daytona_runner" {
  source = "path/to/runner/module"
  
  # Network
  vpc_id    = var.vpc_id
  subnet_id = var.private_subnet_id
  
  # EC2
  ami_id           = data.aws_ami.ubuntu.id
  instance_type    = "t3.xlarge"
  root_volume_size = 100
  
  # Daytona
  api_url      = var.daytona_api_url
  runner_token = var.daytona_runner_token
  
  # Security: SSM only, no SSH
  enable_ssm = true
  enable_ssh = false
  
  # Use company SG
  security_group_ids = ["sg-company-standard"]
  
  # ECR + S3 access
  additional_iam_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]
  
  # Install Docker
  additional_cloudinit_parts = [
    {
      filename     = "docker.sh"
      content_type = "text/x-shellscript"
      content      = <<-EOF
        #!/bin/bash
        apt-get update && apt-get install -y docker.io
        usermod -aG docker ubuntu
      EOF
      merge_type   = null
    }
  ]
  
  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

### Development Setup
```hcl
module "daytona_runner" {
  source = "path/to/runner/module"
  
  vpc_id    = var.vpc_id
  subnet_id = var.public_subnet_id  # Public for easier access
  ami_id    = data.aws_ami.ubuntu.id
  
  api_url      = "https://dev-api.daytona.example.com"
  runner_token = var.dev_runner_token
  
  # Enable SSH for debugging
  enable_ssh      = true
  ssh_cidr_blocks = ["0.0.0.0/0"]  # Restrict in production!
  enable_ssm      = true
  key_name        = "my-dev-key"
  
  tags = {
    Environment = "development"
  }
}
```

### Minimal Setup (Testing)
```hcl
module "daytona_runner" {
  source = "path/to/runner/module"
  
  vpc_id    = "vpc-xxxxx"
  subnet_id = "subnet-xxxxx"
  ami_id    = "ami-xxxxx"
  
  api_url      = "https://api.daytona.example.com"
  runner_token = "test-token"
}
```

## 📊 All Variables

| Variable | Required | Default | Example |
|----------|----------|---------|---------|
| `vpc_id` | ✅ | - | `"vpc-xxxxx"` |
| `subnet_id` | ✅ | - | `"subnet-xxxxx"` |
| `ami_id` | ✅ | - | `"ami-xxxxx"` |
| `api_url` | ✅ | - | `"https://api.example.com"` |
| `runner_token` | ✅ | - | `var.token` |
| `name_prefix` | ❌ | `"daytona"` | `"prod"` |
| `instance_type` | ❌ | `"t3.medium"` | `"t3.xlarge"` |
| `root_volume_size` | ❌ | `50` | `100` |
| `runner_version` | ❌ | `"0.1.0"` | `"0.2.0"` |
| `create_security_group` | ❌ | `true` | `false` |
| `security_group_ids` | ❌ | `[]` | `["sg-xxxxx"]` |
| `enable_ssh` | ❌ | `false` | `true` |
| `ssh_cidr_blocks` | ❌ | `[]` | `["10.0.0.0/8"]` |
| `enable_ssm` | ❌ | `true` | `false` |
| `additional_iam_policy_arns` | ❌ | `[]` | `["arn:aws:..."]` |
| `additional_cloudinit_parts` | ❌ | `[]` | See examples above |
| `tags` | ❌ | `{}` | `{"Env": "prod"}` |

## 🔍 Useful Outputs

```hcl
output "instance_id" {
  value = module.daytona_runner.instance_id
}

output "private_ip" {
  value = module.daytona_runner.instance_private_ip
}

output "security_groups" {
  value = module.daytona_runner.security_group_ids
}

output "iam_role" {
  value = module.daytona_runner.iam_role_name
}
```

## 🛠️ Common Commands

### Connect via SSM
```bash
aws ssm start-session --target i-xxxxx
```

### Check Runner Status
```bash
sudo systemctl status daytona-runner
sudo journalctl -u daytona-runner -f
```

### View Cloud-Init Logs
```bash
sudo cat /var/log/cloud-init-output.log
cloud-init status
```

### Test IAM Permissions
```bash
aws sts get-caller-identity
aws s3 ls  # Test S3 access
```

## 💡 Pro Tips

1. **Always use variables for secrets**: `runner_token = var.runner_token`
2. **Start with defaults, customize later**: Don't over-engineer initially
3. **Test cloud-init scripts locally first**: Debug before adding to module
4. **Use SSM instead of SSH**: More secure, no key management
5. **Tag everything**: Use `tags` for cost tracking
6. **External files for complex scripts**: `file("${path.module}/script.sh")`
7. **Check logs when troubleshooting**: `/var/log/cloud-init-output.log`

## 📚 More Info

- [USAGE.md](USAGE.md) - Comprehensive guide with detailed examples
- [README.md](README.md) - Full documentation
- [example/](example/) - Working example configuration

