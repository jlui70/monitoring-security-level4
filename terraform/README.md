# Terraform Configuration

## Quick Start

1. **Configure variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

2. **Initialize and deploy:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Get outputs:**
   ```bash
   terraform output
   ```

## Required Variables

- `aws_region` - AWS region (default: us-east-1)
- `ec2_instance_type` - EC2 instance type (default: t3.medium)
- `ec2_key_name` - Your AWS key pair name
- `allowed_ssh_ips` - List of IPs allowed to SSH (restrict in production!)

## What This Creates

- **AWS Secrets Manager** - Encrypted secrets with KMS
- **IAM Role & Instance Profile** - For EC2 to access secrets
- **EC2 Instance** - t3.medium running Ubuntu 22.04
- **Security Groups** - Ports 22, 80, 3000, 8080, 9090, 10051
- **Monitoring Stack** - Deployed via user_data script

## Important Notes

- Secrets are randomly generated (32 chars, alphanumeric)
- All secrets are encrypted with AWS KMS
- CloudTrail automatically audits secret access
- The EC2 instance auto-configures on first boot

## Clean Up

```bash
terraform destroy
```

**Note:** This will delete all AWS resources created by this configuration.
