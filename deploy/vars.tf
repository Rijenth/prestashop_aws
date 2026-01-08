variable "AWS_ACCESS_KEY" {
  description = "AWS Access Key"
  type        = string
  sensitive   = true
}

variable "AWS_SECRET_KEY" {
  description = "AWS Secret Key"
  type        = string
  sensitive   = true
}

variable "SSH_PUBLIC_KEY" {
  description = "SSH Public Key for EC2 access"
  type        = string
}

variable "AWS_REGION" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-3"
}

variable "INSTANCE_TYPE" {
  description = "EC2 Instance Type (t2.micro is Free Tier eligible)"
  type        = string
  default     = "t2.micro"
  # Production -> "t3.small"
}

variable "DB_INSTANCE_CLASS" {
  description = "RDS Instance Class (db.t3.micro is Free Tier eligible)"
  type        = string
  default     = "db.t3.micro"
}

variable "DB_NAME" {
  description = "Database name for PrestaShop"
  type        = string
  default     = "prestashop"
}

variable "DB_USER" {
  description = "Database username"
  type        = string
  default     = "prestashop_admin"
}

variable "DB_PASSWORD" {
  description = "Database password (use strong password in production)"
  type        = string
  sensitive   = true
  default     = "HELLO_WORLD_TEST_PASSWORD!"
}

# Auto Scaling Group variables
variable "ASG_MIN_SIZE" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 1
}

variable "ASG_MAX_SIZE" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 4
}

variable "ASG_DESIRED_SIZE" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}

variable "TARGET_CPU_UTILIZATION" {
  description = "Target CPU utilization percentage for auto scaling"
  type        = number
  default     = 50
}

variable "SSH_ALLOWED_CIDR" {
  description = "CIDR block allowed to SSH into ASG instances"
  type        = string
  default     = "0.0.0.0/0" # Change to specific IP in production
}

variable "ASG_INSTANCE_TYPE" {
  description = "Instance type for ASG instances"
  type        = string
  default     = "t2.micro"
}

variable "ENVIRONMENT" {
  description = "Environment name for tagging"
  type        = string
  default     = "production"
}

variable "PROJECT_NAME" {
  description = "Project name for tagging"
  type        = string
  default     = "prestashop"
}