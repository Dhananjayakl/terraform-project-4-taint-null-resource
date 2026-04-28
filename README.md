# terraform-project-4
assignment
Create an EC2 instance make use of Taint and Untaint, null resource.

project execution link
https://claude.ai/share/bcd1ad02-6cf8-4a7c-bd14-497b7d487ef8

steps
1. EC2 Instance with Taint, Untaint & null_resource

1.1 Overview
In this section, we provision an AWS EC2 instance using Terraform, then explore how terraform taint and terraform untaint control resource lifecycle, and how null_resource enables arbitrary automation hooks.

1.2 Project Structure
  File layout
ec2-project/
  main.tf          # EC2 instance + null_resource
  variables.tf     # Input variables
  outputs.tf       # Output values
  providers.tf     # AWS provider config

1.3 providers.tf
  providers.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}
 
provider "aws" {
  region = var.aws_region
}

1.4 variables.tf
  variables.tf
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}
 
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}
 
variable "ami_id" {
  description = "AMI ID for EC2 instance"
  type        = string
  default     = "ami-0c02fb55956c7d316"  # Amazon Linux 2 us-east-1
}
 
variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "terraform-demo-instance"
}

1.5 main.tf — EC2 + null_resource
  main.tf
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

1.6 outputs.tf
  outputs.tf
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

1.7 Deploy Commands
  Terminal
# 1. Initialize Terraform (download providers)
terraform init
 
# 2. Validate configuration
terraform validate
 
# 3. Preview the plan
terraform plan
 
# 4. Apply — provision all resources
terraform apply -auto-approve

 
2. Terraform Taint & Untaint

2.1 What is Taint?
terraform taint marks a specific resource as degraded or corrupted. On the next terraform apply, Terraform will destroy and recreate that resource — even if its configuration has not changed.

📌 Note: Taint does NOT immediately destroy the resource. It only flags it. The actual replacement happens on the next apply.

2.2 Taint Command
  Taint the EC2 instance
# Syntax
terraform taint <resource_type>.<resource_name>
 
# Example — taint the EC2 instance
terraform taint aws_instance.demo
 
# Verify taint status in state
terraform show
 
# Plan will now show: -/+ destroy and then create
terraform plan
 
# Apply to recreate the tainted resource
terraform apply -auto-approve

After tainting, terraform plan output will show:
  Plan output
  # aws_instance.demo is tainted, so it must be replaced
-/+ resource "aws_instance" "demo" {
      ~ id = "i-0abc123..." -> (known after apply)
      ...
    }
 
Plan: 1 to add, 0 to change, 1 to destroy.

2.3 Untaint Command
terraform untaint removes the taint mark from a resource, restoring it to normal. This is useful when you tainted a resource by mistake or the issue was resolved another way.
  Untaint the EC2 instance
# Syntax
terraform untaint <resource_type>.<resource_name>
 
# Example — remove the taint mark
terraform untaint aws_instance.demo
 
# Plan will now show no changes (taint removed)
terraform plan

2.4 Modern Alternative — terraform apply -replace
Since Terraform v0.15.2, the recommended way to force resource recreation is the -replace flag directly in apply. This is safer and more explicit than taint.
  Replace flag (Terraform >= 0.15.2)
# Directly replace without a separate taint step
terraform apply -replace="aws_instance.demo"
 
# Replace multiple resources in one command
terraform apply \
  -replace="aws_instance.demo" \
  -replace="aws_security_group.ec2_sg"

2.5 Taint vs. Replace — Comparison

Term / Command	Description
terraform taint	Marks resource in state file; replacement on next apply (deprecated in v1.0+)
terraform untaint	Removes the taint mark before apply is run
-replace flag	Preferred modern approach; combines taint + apply in one step
When to use taint	Older workflows, or Terraform < 0.15.2
When to use -replace	Terraform >= 0.15.2 — cleaner, safer, explicit

 
3. Exploring null_resource

3.1 What is null_resource?
null_resource is a special Terraform resource that has no real infrastructure backing it. It exists purely to run provisioners (local-exec, remote-exec, file) and to serve as a dependency anchor. It is part of the hashicorp/null provider.

3.2 Providers Setup
  Add null provider to providers.tf
terraform {
  required_providers {
    aws  = { source = "hashicorp/aws",  version = "~> 5.0" }
    null = { source = "hashicorp/null", version = "~> 3.0" }
  }
}

3.3 Key Attributes of null_resource

Term / Command	Description
triggers	Map of arbitrary values; resource re-runs whenever any value changes
id	Auto-generated ID (changes on recreation)
local-exec	Runs a command on the machine running Terraform
remote-exec	SSHs into a remote machine and runs commands
file	Copies files from local to a remote machine

3.4 Use Case 1 — Log Instance Details
  main.tf snippet
resource "null_resource" "log_instance" {
  triggers = {
    instance_id = aws_instance.demo.id
  }
 
  provisioner "local-exec" {
    command = "echo Instance ID: ${aws_instance.demo.id} >> instances.log"
  }
}

3.5 Use Case 2 — Run a Script After Deploy
  Run bootstrap script
resource "null_resource" "bootstrap" {
  depends_on = [aws_instance.demo]
 
  triggers = {
    always_run = timestamp()   # Forces re-run on every apply
  }
 
  provisioner "local-exec" {
    command     = "./scripts/bootstrap.sh ${aws_instance.demo.public_ip}"
    interpreter = ["/bin/bash", "-c"]
  }
}

3.6 Use Case 3 — Remote Exec via SSH
  Remote provisioner
resource "null_resource" "remote_setup" {
  triggers = {
    instance_id = aws_instance.demo.id
  }
 
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/my-key.pem")
    host        = aws_instance.demo.public_ip
  }
 
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y nginx",
      "sudo systemctl start nginx",
    ]
  }
}

3.7 Use Case 4 — Dependency Chain with depends_on
null_resource is powerful as a dependency node — other resources can depend on it, controlling execution order.
  Dependency chaining
# Step 1: Provision instance
resource "aws_instance" "app" { ... }
 
# Step 2: Configure instance (depends on Step 1)
resource "null_resource" "configure" {
  depends_on = [aws_instance.app]
  provisioner "local-exec" {
    command = "ansible-playbook -i ${aws_instance.app.public_ip}, site.yml"
  }
}
 
# Step 3: Run tests (depends on Step 2)
resource "null_resource" "run_tests" {
  depends_on = [null_resource.configure]
  provisioner "local-exec" {
    command = "pytest tests/integration/"
  }


3.8 Triggers Behavior
The triggers argument is a map of string values. null_resource is destroyed and recreated whenever any trigger value changes.
  Trigger examples
# Re-run only when instance changes
triggers = {
  instance_id = aws_instance.demo.id
}
 
# Re-run when instance OR security group changes
triggers = {
  instance_id = aws_instance.demo.id
  sg_id       = aws_security_group.ec2_sg.id
}
 
# ALWAYS re-run on every terraform apply
triggers = {
  always_run = timestamp()
}
 
# Re-run when a script file changes
triggers = {
  script_hash = filemd5("scripts/setup.sh")
}

