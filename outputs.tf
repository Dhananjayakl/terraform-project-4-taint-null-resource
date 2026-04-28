output "instance_id" {
  value       = aws_instance.demo.id
  description = "EC2 Instance ID"
}
 
output "public_ip" {
  value       = aws_instance.demo.public_ip
  description = "Public IP of the EC2 instance"
}
 
output "instance_state" {
  value       = aws_instance.demo.instance_state
  description = "Current state of the instance"
}
