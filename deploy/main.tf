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

# Data source: Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
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

# Second public subnet for ALB (required for multi-AZ)
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.prestashop_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "${var.AWS_REGION}b"
  map_public_ip_on_launch = true

  tags = {
    Name      = "public-subnet-2"
    ManagedBy = "Terraform"
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

# Associate second public subnet with public route table (for internet access)
resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
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

# Security group for Application Load Balancer
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.prestashop_vpc.id

  # Allow HTTP from internet
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from internet"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name      = "alb-sg"
    ManagedBy = "Terraform"
  }
}

# Security group for ASG instances
resource "aws_security_group" "asg_sg" {
  name        = "asg-sg"
  description = "Security group for Auto Scaling Group instances"
  vpc_id      = aws_vpc.prestashop_vpc.id

  # Allow HTTP from ALB only
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Allow HTTP from ALB"
  }

  # Allow SSH from specific CIDR
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.SSH_ALLOWED_CIDR]
    description = "Allow SSH from specified CIDR"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name      = "asg-sg"
    ManagedBy = "Terraform"
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

# Launch template for ASG instances
resource "aws_launch_template" "mon_modele_web" {
  name          = "mon-modele-web"
  description   = "Launch template for ASG web servers"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.ASG_INSTANCE_TYPE
  key_name      = aws_key_pair.prestashop_key.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.asg_sg.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Update system
    dnf update -y

    # Install Nginx
    dnf install -y nginx

    # Get instance metadata
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
    AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

    # Create simple HTML page showing instance info
    cat > /usr/share/nginx/html/index.html <<HTML
    <!DOCTYPE html>
    <html>
    <head>
        <title>ASG Demo Server</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #f0f0f0; }
            .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
            h1 { color: #333; }
            .info { background: #e8f4f8; padding: 15px; border-left: 4px solid #0066cc; margin: 10px 0; }
            .label { font-weight: bold; color: #0066cc; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Auto Scaling Group Demo Server</h1>
            <p>This page is served by an EC2 instance in an Auto Scaling Group behind an Application Load Balancer.</p>

            <div class="info">
                <p><span class="label">Instance ID:</span> $INSTANCE_ID</p>
                <p><span class="label">Private IP:</span> $INSTANCE_IP</p>
                <p><span class="label">Availability Zone:</span> $AVAILABILITY_ZONE</p>
                <p><span class="label">Server:</span> Nginx on Amazon Linux 2023</p>
            </div>

            <p><em>Refresh this page multiple times to see requests distributed across different instances!</em></p>
        </div>
    </body>
    </html>
HTML

    # Start and enable Nginx
    systemctl start nginx
    systemctl enable nginx

    # Configure firewall (if needed)
    systemctl stop firewalld
    systemctl disable firewalld
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name      = "asg-instance"
      ManagedBy = "Terraform"
      Project   = var.PROJECT_NAME
    }
  }

  tags = {
    Name      = "mon-modele-web"
    ManagedBy = "Terraform"
  }
}

# Target group for ASG instances
resource "aws_lb_target_group" "asg_target_group" {
  name     = "asg-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.prestashop_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = {
    Name      = "asg-target-group"
    ManagedBy = "Terraform"
  }
}

# Application Load Balancer
resource "aws_lb" "mon_alb" {
  name               = "mon-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets = [
    aws_subnet.prestashop_public_subnet.id,
    aws_subnet.public_subnet_2.id
  ]

  enable_deletion_protection = false

  tags = {
    Name      = "mon-alb"
    ManagedBy = "Terraform"
    Project   = var.PROJECT_NAME
  }
}

# Listener for ALB (HTTP:80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.mon_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg_target_group.arn
  }

  tags = {
    Name      = "alb-http-listener"
    ManagedBy = "Terraform"
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "mon_asg_web" {
  name                      = "mon-asg-web"
  desired_capacity          = var.ASG_DESIRED_SIZE
  min_size                  = var.ASG_MIN_SIZE
  max_size                  = var.ASG_MAX_SIZE
  health_check_type         = "ELB"
  health_check_grace_period = 300
  vpc_zone_identifier = [
    aws_subnet.prestashop_public_subnet.id,
    aws_subnet.public_subnet_2.id
  ]
  target_group_arns = [aws_lb_target_group.asg_target_group.arn]

  launch_template {
    id      = aws_launch_template.mon_modele_web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "asg-web-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "Terraform"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.ENVIRONMENT
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Target tracking scaling policy (CPU utilization)
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "cpu-target-tracking-policy"
  autoscaling_group_name = aws_autoscaling_group.mon_asg_web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.TARGET_CPU_UTILIZATION
  }
}
