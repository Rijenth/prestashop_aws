output "prestashop_url" {
  description = "URL to access PrestaShop storefront"
  value       = "http://${aws_instance.prestashop_web.public_ip}"
}

output "prestashop_admin_url" {
  description = "URL to access PrestaShop admin panel"
  value       = "http://${aws_instance.prestashop_web.public_ip}/admin-dev"
}

output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.prestashop_web.public_ip
}

output "prestashop_public_ip" {
  description = "Public IP for Ansible inventory"
  value       = aws_instance.prestashop_web.public_ip
}

output "ec2_instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.prestashop_web.id
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint (hostname only, without port)"
  value       = aws_db_instance.prestashop_db.address
}

output "rds_database_name" {
  description = "RDS Database name"
  value       = aws_db_instance.prestashop_db.db_name
}

output "ssh_connection_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = "ssh -i /path/to/your/ssh_keys.pem ubuntu@${aws_instance.prestashop_web.public_ip}"
}

output "vpc_id" {
  description = "VPC ID (Default VPC)"
  value       = data.aws_vpc.default.id
}
