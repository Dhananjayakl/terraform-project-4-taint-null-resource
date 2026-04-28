# Create a Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-demo-sg"
  description = "Allow SSH and HTTP"
 
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
 
# EC2 Instance
resource "aws_instance" "demo" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
 
  tags = {
    Name        = var.instance_name
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}
 
# null_resource — runs a local command after instance is ready
resource "null_resource" "post_provisioner" {
  # Re-run whenever the EC2 instance ID changes
  triggers = {
    instance_id = aws_instance.demo.id
  }
 
  provisioner "local-exec" {
    command = <<EOT
      echo "Instance ${aws_instance.demo.id} is up"
      echo "Public IP: ${aws_instance.demo.public_ip}"
    EOT
  }
}
