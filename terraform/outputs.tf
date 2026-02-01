# OpenClaw AWS Secure Deploy - Terraform Outputs

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.openclaw.id
}

output "public_ip" {
  description = "Public IP address (use this for initial SSH, before Tailscale)"
  value       = var.create_elastic_ip ? aws_eip.openclaw[0].public_ip : aws_instance.openclaw.public_ip
}

output "private_ip" {
  description = "Private IP address"
  value       = aws_instance.openclaw.private_ip
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.openclaw.id
}

output "ssh_command" {
  description = "SSH command to connect (use your key file)"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${var.create_elastic_ip ? aws_eip.openclaw[0].public_ip : aws_instance.openclaw.public_ip}"
}

output "next_steps" {
  description = "Next steps after Terraform apply"
  value       = <<-EOT
    
    ============================================
    OpenClaw EC2 Instance Created Successfully!
    ============================================
    
    Next steps:
    
    1. SSH into your instance:
       ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${var.create_elastic_ip ? aws_eip.openclaw[0].public_ip : aws_instance.openclaw.public_ip}
    
    2. Run the setup script:
       cd ~/openclaw-setup && ./setup.sh
    
    3. Follow the prompts to:
       - Configure Tailscale (you'll authenticate via browser)
       - Run 'openclaw onboard' when prompted
       - Enter your Discord/Telegram user ID
    
    4. After Tailscale is configured, update the security group
       to remove public SSH access (security best practice)
    
    Your Tailscale IP will be shown during setup - use that
    for all future SSH connections instead of the public IP.
    
  EOT
}
