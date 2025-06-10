output "public_ip" {
  value       = aws_instance.clickhouse_server.public_ip
  description = "Public IPv4 of the EC2 instance"
}

output "clickhouse_password" {
  value       = random_password.clickhouse_password.result
  description = "Generated ClickHouse password"
  sensitive   = true
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh -i ec2-clickhouse ubuntu@${aws_instance.clickhouse_server.public_ip}"
}
