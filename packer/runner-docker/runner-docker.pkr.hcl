// Copyright (c) 2025 Daytona
// Licensed under the MIT License - see LICENSE file for details

packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ami_name_prefix" {
  type    = string
  default = "daytona-runner-docker"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "sysbox_version" {
  type        = string
  default     = "v0.6.7"
  description = "Sysbox version to install"
}

variable "docker_version" {
  type        = string
  default     = "5:28.3.2-1~ubuntu.24.04~noble"
  description = "Docker version to install"
}

variable "ami_public" {
  type        = bool
  default     = false
  description = "Make AMI publicly accessible"
}

variable "ami_regions" {
  type        = list(string)
  default     = []
  description = "List of regions to copy the AMI to"
}

source "amazon-ebs" "ubuntu" {
  ami_name        = "${var.ami_name_prefix}-ubuntu-24.04-amd64-{{isotime \"20060102\"}}"
  ami_description = "Ubuntu 24.04 with Docker ${var.docker_version} and Sysbox ${var.sysbox_version} for Daytona runners"
  instance_type   = var.instance_type
  region          = var.aws_region

  ami_groups  = var.ami_public ? ["all"] : []
  ami_regions = var.ami_regions

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }

  ssh_username = var.ssh_username

  tags = {
    Name       = "${var.ami_name_prefix}-{{timestamp}}"
    OS         = "Ubuntu 24.04"
    Components = "Docker, Sysbox"
    ManagedBy  = "Packer"
  }
}

build {
  name    = "runner-docker"
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Updating system packages...'",
      "sudo apt-get update",
      "sudo apt-get upgrade -y"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Installing Docker prerequisites...'",
      "sudo apt-get install -y ca-certificates curl"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Adding Docker GPG key...'",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
      "sudo chmod a+r /etc/apt/keyrings/docker.asc"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Adding Docker repository...'",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
    ]
  }

  provisioner "shell" {
    environment_vars = [
      "DOCKER_VERSION=${var.docker_version}"
    ]
    inline = [
      "echo 'Installing Docker...'",
      "sudo apt-get update",
      "sudo apt-get install -y docker-ce=$DOCKER_VERSION docker-ce-cli=$DOCKER_VERSION containerd.io docker-buildx-plugin docker-compose-plugin"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Configuring Docker...'",
      "sudo usermod -aG docker ${var.ssh_username}",
      "sudo systemctl enable docker",
      "sudo systemctl start docker"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Installing Sysbox dependencies...'",
      "sudo apt-get install -y jq fuse"
    ]
  }

  provisioner "shell" {
    environment_vars = [
      "SYSBOX_VERSION=${var.sysbox_version}"
    ]
    inline = [
      "echo 'Downloading and installing Sysbox...'",
      "cd /tmp",
      "echo \"Installing Sysbox version: $SYSBOX_VERSION\"",
      "wget -q https://downloads.nestybox.com/sysbox/releases/$SYSBOX_VERSION/sysbox-ce_$${SYSBOX_VERSION#v}-0.linux_amd64.deb -O sysbox.deb",
      "sudo apt-get install -y ./sysbox.deb",
      "rm sysbox.deb"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Configuring Docker daemon...'",
      "sudo mkdir -p /etc/docker",
      <<-EOF
      sudo tee /etc/docker/daemon.json > /dev/null <<'DAEMON'
{
  "icc": false,
  "bip": "172.20.0.1/16",
  "default-address-pools": [
    {
      "base": "172.25.0.0/16",
      "size": 24
    }
  ],
  "runtimes": {
    "sysbox-runc": {
      "path": "/usr/bin/sysbox-runc"
    }
  }
}
DAEMON
      EOF
      ,
      "sudo systemctl restart docker",
      "sleep 5",
      "sudo systemctl is-active --quiet docker && echo 'Docker restarted successfully' || (echo 'Docker failed to restart' && exit 1)"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Enabling Sysbox services...'",
      "sudo systemctl enable sysbox",
      "sudo systemctl start sysbox"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Cleaning up...'",
      "sudo apt-get autoremove -y",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Verifying installations...'",
      "docker --version",
      "sudo sysbox-runc --version"
    ]
  }
}
