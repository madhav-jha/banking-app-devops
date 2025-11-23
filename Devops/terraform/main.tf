terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ------------------ PROVIDER ------------------
provider "aws" {
  region = "ap-south-1"   # Mumbai
}

# ------------------ VARIABLES ------------------
variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI - Mumbai"
  default     = "ami-087d1c9a513324697"
}

variable "key_name" {
  description = "Existing AWS keypair name"
  default     = "devops-key"
}

variable "vpc_id" {
  description = "AWS VPC"
  default     = "vpc-0ad16e491bff51239"
}

# ------------------ SECURITY GROUP ------------------
resource "aws_security_group" "devops_sg" {
  name        = "devops-sg"
  description = "Security group for DevOps project"
  vpc_id      = var.vpc_id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NodePort service
  ingress {
    from_port   = 31002
    to_port     = 31002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # K8s API Server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Everything outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------ INSTANCES ------------------

# JENKINS MASTER
resource "aws_instance" "jenkins_master" {
  ami                    = var.ami_id
  instance_type          = "t3.medium"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.devops_sg.id]

  tags = {
    Name = "jenkins-master"
    Role = "jenkins_master"
  }
}

# JENKINS AGENT
resource "aws_instance" "jenkins_agent" {
  ami                    = var.ami_id
  instance_type          = "t3.medium"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.devops_sg.id]

  tags = {
    Name = "jenkins-agent"
    Role = "jenkins_agent"
  }
}

# K8S MASTER
resource "aws_instance" "k8s_master" {
  ami                    = var.ami_id
  instance_type          = "t3.medium"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.devops_sg.id]

  tags = {
    Name = "k8s-master"
    Role = "k8s_master"
  }
}

# K8S WORKER NODES
resource "aws_instance" "k8s_worker" {
  count                  = 3
  ami                    = var.ami_id
  instance_type          = "t3.small"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.devops_sg.id]

  tags = {
    Name = "k8s-worker-${count.index + 1}"
    Role = "k8s_worker"
  }
}

# MONITORING NODE
resource "aws_instance" "monitoring" {
  ami                    = var.ami_id
  instance_type          = "t3.small"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.devops_sg.id]

  tags = {
    Name = "monitoring-node"
    Role = "monitoring"
  }
}

# ------------------ ELASTIC IPS ------------------
# 3 static public IPs: Jenkins master, Jenkins agent, K8s master

resource "aws_eip" "jenkins_master_eip" {
  vpc      = true
  instance = aws_instance.jenkins_master.id

  tags = {
    Name = "jenkins-master-eip"
  }
}

resource "aws_eip" "jenkins_agent_eip" {
  vpc      = true
  instance = aws_instance.jenkins_agent.id

  tags = {
    Name = "jenkins-agent-eip"
  }
}

resource "aws_eip" "k8s_master_eip" {
  vpc      = true
  instance = aws_instance.k8s_master.id

  tags = {
    Name = "k8s-master-eip"
  }
}

# ------------------ OUTPUTS ------------------
output "jenkins_master_eip" {
  description = "Elastic IP for Jenkins master"
  value       = aws_eip.jenkins_master_eip.public_ip
}

output "jenkins_agent_eip" {
  description = "Elastic IP for Jenkins agent"
  value       = aws_eip.jenkins_agent_eip.public_ip
}

output "k8s_master_eip" {
  description = "Elastic IP for K8s master"
  value       = aws_eip.k8s_master_eip.public_ip
}

output "k8s_worker_ips" {
  description = "Public IPs of K8s worker nodes (ephemeral)"
  value       = [for i in aws_instance.k8s_worker : i.public_ip]
}

output "monitoring_ip" {
  description = "Public IP of monitoring node"
  value       = aws_instance.monitoring.public_ip
}