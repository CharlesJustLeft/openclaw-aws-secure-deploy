# Terraform Configuration for OpenClaw

This Terraform configuration creates a hardened AWS EC2 instance ready for OpenClaw deployment.

## What It Creates

- **EC2 Instance**: Ubuntu 24.04 LTS with encrypted EBS volume
- **Security Group**: Only Tailscale UDP (41641) and temporary SSH allowed
- **Optional Elastic IP**: For stable addressing

## Prerequisites

1. [Terraform](https://terraform.io) installed (v1.0+)
2. AWS CLI configured with credentials
3. An existing EC2 key pair in your target region

## Usage

### Quick Start

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan -var="key_name=your-key-name"

# Apply (creates resources)
terraform apply -var="key_name=your-key-name"
```

### With Custom Variables

Create a `terraform.tfvars` file:

```hcl
aws_region    = "us-west-2"
instance_name = "my-openclaw"
instance_type = "t3.large"
key_name      = "my-aws-key"
volume_size   = 50
```

Then run:

```bash
terraform apply
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `us-east-2` |
| `instance_name` | Name tag for instance | `openclaw-secure` |
| `instance_type` | EC2 instance type | `t3.medium` |
| `key_name` | **Required** - EC2 key pair name | - |
| `volume_size` | EBS volume size in GB | `30` |
| `allow_ssh_from` | CIDR for SSH access | `["0.0.0.0/0"]` |
| `create_elastic_ip` | Create Elastic IP | `false` |

## After Deployment

1. SSH into the instance using the output command
2. Run `./setup.sh` to complete security hardening
3. After Tailscale is configured, **remove public SSH access** from the security group

### Removing Public SSH Access

After Tailscale is working, run:

```bash
# Get the security group ID from outputs
SG_ID=$(terraform output -raw security_group_id)

# Remove the SSH rule (you'll use Tailscale IP for SSH now)
aws ec2 revoke-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Security Notes

- The security group initially allows SSH from anywhere for initial setup
- **Always restrict SSH to Tailscale after setup completes**
- EBS volumes are encrypted by default
- Instance metadata service (IMDSv2) is used by default on newer instances
