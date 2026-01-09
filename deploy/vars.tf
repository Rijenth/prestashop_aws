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
  default     = "t3.micro"
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
}

variable "DB_PASSWORD" {
  description = "Database password (use strong password in production)"
  type        = string
  sensitive   = true
}
