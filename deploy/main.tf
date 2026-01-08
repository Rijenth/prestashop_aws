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

# VPC
resource "aws_vpc" "prestashop_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "prestashop-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "prestashop_igw" {
  vpc_id = aws_vpc.prestashop_vpc.id

  tags = {
    Name = "prestashop-igw"
  }
}

# Public Subnet
resource "aws_subnet" "prestashop_public_subnet" {
  vpc_id                  = aws_vpc.prestashop_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.AWS_REGION}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "prestashop-public-subnet"
  }
}

# Private Subnet 1
resource "aws_subnet" "prestashop_private_subnet_1" {
  vpc_id            = aws_vpc.prestashop_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.AWS_REGION}a"

  tags = {
    Name = "prestashop-private-subnet-1"
  }
}

# Private Subnet 2 (required for RDS subnet group)
resource "aws_subnet" "prestashop_private_subnet_2" {
  vpc_id            = aws_vpc.prestashop_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.AWS_REGION}b"

  tags = {
    Name = "prestashop-private-subnet-2"
  }
}

# Route Table
resource "aws_route_table" "prestashop_public_rt" {
  vpc_id = aws_vpc.prestashop_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prestashop_igw.id
  }

  tags = {
    Name = "prestashop-public-rt"
  }
}

# Route Table Association (Public)
resource "aws_route_table_association" "prestashop_public_rta" {
  subnet_id      = aws_subnet.prestashop_public_subnet.id
  route_table_id = aws_route_table.prestashop_public_rt.id
}

# Private Route Table (for RDS subnets)
resource "aws_route_table" "prestashop_private_rt" {
  vpc_id = aws_vpc.prestashop_vpc.id

  tags = {
    Name = "prestashop-private-rt"
  }
}

# Private Route Table Association for Subnet 1
resource "aws_route_table_association" "prestashop_private_rta_1" {
  subnet_id      = aws_subnet.prestashop_private_subnet_1.id
  route_table_id = aws_route_table.prestashop_private_rt.id
}

# Private Route Table Association for Subnet 2
resource "aws_route_table_association" "prestashop_private_rta_2" {
  subnet_id      = aws_subnet.prestashop_private_subnet_2.id
  route_table_id = aws_route_table.prestashop_private_rt.id
}

# Security Group for EC2 (Web Server)
resource "aws_security_group" "prestashop_web_sg" {
  name        = "prestashop-web-sg"
  description = "Security group for PrestaShop web server"
  vpc_id      = aws_vpc.prestashop_vpc.id

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
  vpc_id      = aws_vpc.prestashop_vpc.id

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

# DB Subnet Group
resource "aws_db_subnet_group" "prestashop_db_subnet_group" {
  name       = "prestashop-db-subnet-group"
  subnet_ids = [aws_subnet.prestashop_private_subnet_1.id, aws_subnet.prestashop_private_subnet_2.id]

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
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.INSTANCE_TYPE
  key_name               = aws_key_pair.prestashop_key.key_name
  subnet_id              = aws_subnet.prestashop_public_subnet.id
  vpc_security_group_ids = [aws_security_group.prestashop_web_sg.id]

  tags = {
    Name = "prestashop-web-server"
  }

  depends_on = [aws_db_instance.prestashop_db]
}

# Elastic IP for EC2
resource "aws_eip" "prestashop_eip" {
  instance = aws_instance.prestashop_web.id
  domain   = "vpc"

  tags = {
    Name = "prestashop-eip"
  }
}
