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

resource "aws_subnet" "public-subnet-terraform-1" {
  vpc_id            = aws_vpc.terraform-vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-1a"

  tags = merge(local.common_tags, {
    Name = "public-subnet-terraform-1"
  })
}

resource "aws_subnet" "public-subnet-terraform-2" {
  vpc_id            = aws_vpc.terraform-vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"

  tags = merge(local.common_tags, {
    Name = "public-subnet-terraform-2"
  })
}

resource "aws_subnet" "private-subnet-terraform" {
  vpc_id            = aws_vpc.terraform-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = merge(local.common_tags, {
    Name = "private-subnet-terraform"
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

resource "aws_route_table_association" "public-1" {
  subnet_id      = aws_subnet.public-subnet-terraform-1.id
  route_table_id = aws_route_table.terraform-rtb.id
}

resource "aws_route_table_association" "public-2" {
  subnet_id      = aws_subnet.public-subnet-terraform-2.id
  route_table_id = aws_route_table.terraform-rtb.id
}

resource "aws_security_group" "secgrp-alb" {
  description = "Security group for ALB"
  name        = "secgrp-alb"
  vpc_id      = aws_vpc.terraform-vpc.id

  # Allow inbound HTTP traffic from the internet
  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "secgrp-alb"
  })
}

resource "aws_security_group" "secgrp-web-server" {
  description = "Security group for web servers in private subnets"
  name        = "secgrp-web-server"
  vpc_id      = aws_vpc.terraform-vpc.id

  # Allow inbound HTTP traffic from the ALB security group
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.secgrp-alb.id]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "secgrp-web-server"
  })
}

resource "aws_lb" "terraform_alb" {
  name               = "terraform_alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.secgrp-alb.id]
  subnets            = [
    aws_subnet.public-subnet-terraform-1.id,
    aws_subnet.public-subnet-terraform-2.id
  ]

  enable_deletion_protection = false

  tags = merge(local.common_tags, {
    Name = "terraform_alb"
  })
}

resource "aws_lb_target_group" "terraform_alb_tg" {
  name     = "terraform_alb_tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraform-vpc.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = merge(local.common_tags, {
    Name = "terraform_alb_tg"
  })
}

resource "aws_lb_listener" "app_lb_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_instance" "web-server-1" {
  ami                         = "ami-095a8f574cb0ac0d0"
  associate_public_ip_address = false
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private-subnet-terraform.id
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
              PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
              PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
              echo "<html><body><h1>Hello from Terraform web server 1</h1><p>Public IP: $PUBLIC_IP</p><p>Private IP: $PRIVATE_IP</p></body></html>" | sudo tee /var/www/html/index.html
              EOF

  tags = merge(local.common_tags, {
    Name = "terraform-web-server-1"
  })

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_lb.app_lb, aws_lb_target_group.app_tg]
}

resource "aws_instance" "web-server-2" {
  ami                         = "ami-095a8f574cb0ac0d0"
  associate_public_ip_address = false
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private-subnet-terraform.id
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
              PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
              PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
              echo "<html><body><h1>Hello from Terraform web server 2</h1><p>Public IP: $PUBLIC_IP</p><p>Private IP: $PRIVATE_IP</p></body></html>" | sudo tee /var/www/html/index.html
              EOF

  tags = merge(local.common_tags, {
    Name = "terraform-web-server-2"
  })

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_lb.app_lb, aws_lb_target_group.app_tg]
}

resource "aws_lb_target_group_attachment" "web_server_1_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.web-server-1.id
  port             = 80

  depends_on = [aws_instance.web-server-1]
}

resource "aws_lb_target_group_attachment" "web_server_2_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.web-server-2.id
  port             = 80

  depends_on = [aws_instance.web-server-2]
}

output "web_server_1_private_ip" {
  description = "The private IP address of web server 1"
  value       = aws_instance.web-server-1.private_ip
}

output "web_server_2_private_ip" {
  description = "The private IP address of web server 2"
  value       = aws_instance.web-server-2.private_ip
}

output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = aws_lb.app_lb.dns_name
}
