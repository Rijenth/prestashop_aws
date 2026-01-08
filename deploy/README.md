# PrestaShop AWS Terraform Deployment

This directory contains Terraform configuration to deploy PrestaShop on AWS infrastructure.

## Architecture

The infrastructure uses **AWS Free Tier eligible** resources where possible:
- **VPC** with public and private subnets across multiple availability zones
- **EC2 instance** (t2.micro - Free Tier) running PrestaShop via Docker in a public subnet
- **RDS MySQL 8.0** (db.t3.micro - Free Tier) in private subnets for the database
- **20GB EBS Storage** (Free Tier) for both EC2 and RDS
- **Security Groups** restricting access appropriately
- **Elastic IP** for stable public IP address (free when attached to running instance)
- **Internet Gateway** and routing for public access

## Prerequisites

1. AWS Account with appropriate permissions
2. Terraform >= 1.2 installed
3. SSH key pair for EC2 access
4. AWS credentials (Access Key and Secret Key)

## Setup Instructions

### 1. Configure Variables

Copy the example variables file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and fill in your values:
- `AWS_ACCESS_KEY`: Your AWS access key
- `AWS_SECRET_KEY`: Your AWS secret key
- `SSH_PUBLIC_KEY`: Your SSH public key content (generate with `ssh-keygen` if needed)
- `DB_PASSWORD`: Strong password for the database

### 2. Generate SSH Key Pair (if needed)

```bash
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
```

Copy the content of `~/.ssh/id_rsa.pub` to the `SSH_PUBLIC_KEY` variable.

### 3. Deploy Infrastructure

Initialize Terraform:
```bash
terraform init
```

Review the planned changes:
```bash
terraform plan
```

Apply the configuration:
```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 4. Access PrestaShop

After deployment completes (typically 5-10 minutes), Terraform will output:
- `prestashop_url`: URL to access the storefront
- `prestashop_admin_url`: URL to access the admin panel
- `ec2_public_ip`: Public IP of the web server
- `ssh_connection_command`: Command to SSH into the server

**Default Admin Credentials:**
- Email: `demo@prestashop.com`
- Password: `prestashop_demo`

**Note:** PrestaShop installation may take a few minutes after the EC2 instance starts. If you get a connection error, wait 2-3 minutes and try again.

## Customization

You can customize the deployment by modifying variables in `terraform.tfvars`:

- `AWS_REGION`: Change deployment region (default: eu-west-3)
- `INSTANCE_TYPE`: Change EC2 instance size (default: t2.micro - Free Tier)
- `DB_INSTANCE_CLASS`: Change RDS instance size (default: db.t3.micro - Free Tier)
- `DB_NAME`: Change database name
- `DB_USER`: Change database username

**Note:** If you need more performance, you can upgrade to larger instances (e.g., t2.medium for EC2), but this will incur additional costs beyond the Free Tier.

## Monitoring and Troubleshooting

### Check PrestaShop Installation Status

SSH into the EC2 instance:
```bash
ssh -i /path/to/your/private-key.pem ubuntu@<ec2_public_ip>
```

Check Docker container status:
```bash
docker ps
docker logs prestashop
```

### View RDS Database

The RDS database is in a private subnet and only accessible from the EC2 instance for security.

## Cleanup

To destroy all infrastructure and avoid AWS charges:

```bash
terraform destroy
```

Type `yes` when prompted.

**Warning:** This will permanently delete all resources including the database.

## Cost Estimation

### AWS Free Tier (First 12 Months)

With the default configuration, this infrastructure is **FREE** for the first 12 months under AWS Free Tier:
- **EC2 t2.micro**: 750 hours/month (Free Tier)
- **RDS db.t3.micro**: 750 hours/month (Free Tier)
- **EBS Storage**: 30GB total (20GB used - Free Tier)
- **Data Transfer**: 15GB outbound/month (Free Tier)
- **VPC, Security Groups, Elastic IP**: Free

**Total: $0/month** (within Free Tier limits for single instance)

## TODO:
- SSH access is open to all IPs (0.0.0.0/0) - consider restricting to your IP
- Change default PrestaShop admin credentials after first login
- Use strong passwords for database and admin access
- Consider adding SSL/TLS certificate for HTTPS in production
