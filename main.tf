terraform {
  required_version = ">= 1.7.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  common_tags = {
    created_by = "terraform"
  }
}

resource "aws_vpc" "terraform-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = merge(local.common_tags, {
    Name = "terraform-vpc"
  })
}

resource "aws_subnet" "public-subnet-terraform" {
  vpc_id     = aws_vpc.terraform-vpc.id
  cidr_block = "10.0.0.0/24"
  tags = merge(local.common_tags, {
    Name = "public-subnet-terraform"
  })
}

resource "aws_internet_gateway" "terraform-igw" {
  vpc_id = aws_vpc.terraform-vpc.id

  tags = merge(local.common_tags, {
    Name = "terraform-igw"
  })
}

resource "aws_route_table" "terraform-rtb" {
  vpc_id = aws_vpc.terraform-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform-igw.id
  }

  tags = merge(local.common_tags, {
    Name = "terraform-rtb"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public-subnet-terraform.id
  route_table_id = aws_route_table.terraform-rtb.id
}


resource "aws_security_group" "secgrp-web-server" {
  description = "Security group allowing HTTP(port 80) and HTTPS(port 443)"
  name        = "secgrp-web-server"
  vpc_id      = aws_vpc.terraform-vpc.id

  # Allow inbound HTTP traffic on port 80
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound HTTP traffic on port 443
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = merge(local.common_tags, {
    Name = "sg-web-server"
  })

}

resource "aws_instance" "web-server" {
  ami                         = "ami-0866a3c8686eaeeba"
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public-subnet-terraform.id
  vpc_security_group_ids      = [aws_security_group.secgrp-web-server.id]

  root_block_device {
    delete_on_termination = true
    volume_size           = 10
    volume_type           = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y apache2
              sudo systemctl start apache2
              sudo systemctl enable apache2
              echo "Hello from Terraform" | sudo tee /var/www/html/index.html
              EOF

  tags = merge(local.common_tags, {
    Name = "terraform-web-server"
  })

  lifecycle {
    create_before_destroy = true
  }
}
