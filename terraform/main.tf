# OpenClaw AWS Secure Deploy - Terraform Configuration
# This creates a hardened EC2 instance ready for OpenClaw deployment

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# Get latest Ubuntu 24.04 LTS AMI
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

# Security Group - Minimal exposure
resource "aws_security_group" "openclaw" {
  name        = "${var.instance_name}-sg"
  description = "Security group for OpenClaw - only Tailscale allowed"

  # Tailscale UDP - Required for VPN handshake
  ingress {
    description = "Tailscale UDP"
    from_port   = 41641
    to_port     = 41641
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Temporary SSH - Will be restricted to Tailscale after setup
  # IMPORTANT: Remove this rule after Tailscale is configured!
  ingress {
    description = "SSH (temporary - restrict after Tailscale setup)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allow_ssh_from
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.instance_name}-sg"
    Project = "openclaw-secure"
  }
}

# EC2 Instance
resource "aws_instance" "openclaw" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.openclaw.id]

  root_block_device {
    volume_size           = var.volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # Enable detailed monitoring (optional, costs extra)
  monitoring = var.enable_detailed_monitoring

  # User data script - basic setup
  user_data = <<-EOF
    #!/bin/bash
    # Update system on first boot
    apt-get update
    apt-get upgrade -y
    
    # Install basic tools
    apt-get install -y curl wget git ufw fail2ban unattended-upgrades
    
    # Enable automatic security updates
    dpkg-reconfigure -plow unattended-upgrades
    
    # Create setup directory
    mkdir -p /home/ubuntu/openclaw-setup
    
    # Download setup script
    curl -sL https://raw.githubusercontent.com/YOUR_USERNAME/openclaw-aws-secure-deploy/main/scripts/setup.sh \
      -o /home/ubuntu/openclaw-setup/setup.sh
    chmod +x /home/ubuntu/openclaw-setup/setup.sh
    chown -R ubuntu:ubuntu /home/ubuntu/openclaw-setup
    
    echo "OpenClaw setup files downloaded. Run: cd ~/openclaw-setup && ./setup.sh"
  EOF

  tags = {
    Name    = var.instance_name
    Project = "openclaw-secure"
  }
}

# Elastic IP (optional but recommended for stable address)
resource "aws_eip" "openclaw" {
  count    = var.create_elastic_ip ? 1 : 0
  instance = aws_instance.openclaw.id
  domain   = "vpc"

  tags = {
    Name    = "${var.instance_name}-eip"
    Project = "openclaw-secure"
  }
}
