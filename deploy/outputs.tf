output "prestashop_url" {
  description = "URL to access PrestaShop storefront"
  value       = "http://${aws_eip.prestashop_eip.public_ip}"
}

output "prestashop_admin_url" {
  description = "URL to access PrestaShop admin panel"
  value       = "http://${aws_eip.prestashop_eip.public_ip}/admin-dev"
}

output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.prestashop_eip.public_ip
}

output "prestashop_public_ip" {
  description = "Public IP for Ansible inventory"
  value       = aws_eip.prestashop_eip.public_ip
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
  value       = "ssh -i /path/to/your/ssh_keys.pem ubuntu@${aws_eip.prestashop_eip.public_ip}"
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.prestashop_vpc.id
}

# Auto Scaling Group outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.mon_alb.dns_name
}

output "asg_demo_url" {
  description = "URL to access the ASG demo page"
  value       = "http://${aws_lb.mon_alb.dns_name}"
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.mon_asg_web.name
}

output "target_group_arn" {
  description = "ARN of the ALB target group"
  value       = aws_lb_target_group.asg_target_group.arn
}
