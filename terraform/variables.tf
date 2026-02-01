# OpenClaw AWS Secure Deploy - Terraform Variables

variable "aws_region" {
  description = "AWS region to deploy in"
  type        = string
  default     = "us-east-2"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "openclaw-secure"
}

variable "instance_type" {
  description = "EC2 instance type. t3.medium is recommended minimum for OpenClaw"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name of existing EC2 key pair for SSH access"
  type        = string
}

variable "volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}

variable "allow_ssh_from" {
  description = "CIDR blocks allowed to SSH (temporary - will be restricted to Tailscale)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Open initially, restrict after Tailscale setup
}

variable "create_elastic_ip" {
  description = "Whether to create an Elastic IP for stable addressing"
  type        = bool
  default     = false
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring (additional cost)"
  type        = bool
  default     = false
}
