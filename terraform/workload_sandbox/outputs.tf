output "instance_id" {
  description = "ID honeypot EC2 instance"
  value       = aws_instance.honeypot.id
}

output "public_ip" {
  description = "Veřejná IP adresa honeypotu — sem budou mířit útoky"
  value       = aws_instance.honeypot.public_ip
}

output "security_group_id" {
  description = "ID security group honeypotu"
  value       = aws_security_group.honeypot.id
}

output "vpc_id" {
  description = "ID vlastní VPC honeypotu"
  value       = aws_vpc.honeypot.id
}
