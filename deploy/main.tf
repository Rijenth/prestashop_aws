provider "aws" {
  region     = var.AWS_REGION
  access_key = var.AWS_ACCESS_KEY
  secret_key = var.AWS_SECRET_KEY
}

# Data source to fetch latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Use Default VPC
data "aws_vpc" "default" {
  default = true
}

# Get all subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group for EC2 (Web Server)
resource "aws_security_group" "prestashop_web_sg" {
  name        = "prestashop-web-sg"
  description = "Security group for PrestaShop web server"
  vpc_id      = data.aws_vpc.default.id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic"
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH access"
  }

  # Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "prestashop-web-sg"
  }
}

# Security Group for RDS
resource "aws_security_group" "prestashop_db_sg" {
  name        = "prestashop-db-sg"
  description = "Security group for PrestaShop database"
  vpc_id      = data.aws_vpc.default.id

  # MySQL
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.prestashop_web_sg.id]
    description     = "Allow MySQL access from web server"
  }

  # Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "prestashop-db-sg"
  }
}

# DB Subnet Group (using default VPC subnets)
resource "aws_db_subnet_group" "prestashop_db_subnet_group" {
  name       = "prestashop-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "prestashop-db-subnet-group"
  }
}

# RDS MySQL Instance
resource "aws_db_instance" "prestashop_db" {
  identifier              = "prestashop-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = var.DB_INSTANCE_CLASS
  allocated_storage       = 20 # Free Tier: 20GB
  storage_type            = "gp2"
  db_name                 = var.DB_NAME
  username                = var.DB_USER
  password                = var.DB_PASSWORD
  db_subnet_group_name    = aws_db_subnet_group.prestashop_db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.prestashop_db_sg.id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  backup_retention_period = 0 # Free Tier: disable automated backups to stay within free tier

  tags = {
    Name = "prestashop-db"
  }
}

# Key Pair
resource "aws_key_pair" "prestashop_key" {
  key_name   = "prestashop-key"
  public_key = var.SSH_PUBLIC_KEY
}

# EC2 Instance
resource "aws_instance" "prestashop_web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.INSTANCE_TYPE
  key_name                    = aws_key_pair.prestashop_key.key_name
  subnet_id                   = tolist(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.prestashop_web_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "prestashop-web-server"
  }

  depends_on = [aws_db_instance.prestashop_db]
}

# Note: Elastic IP removed to avoid AWS Free Tier limits
# EC2 instance will use its auto-assigned public IP instead
# IP will change if instance is stopped/started (but not on reboot)
