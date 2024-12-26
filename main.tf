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
resource "aws_eip" "terraform-nat-eip" {
  domain = "vpc"
}

resource "aws_route_table" "terraform-private-rtb" {
  vpc_id = aws_vpc.terraform-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.terraform-nat-gateway.id
  }

  tags = merge(local.common_tags, {
    Name = "terraform-private-rtb"
  })
}

resource "aws_route_table_association" "private-association" {
  subnet_id      = aws_subnet.private-subnet-terraform.id
  route_table_id = aws_route_table.terraform-private-rtb.id
}

resource "aws_nat_gateway" "terraform-nat-gateway" {
  allocation_id = aws_eip.terraform-nat-eip.id
  subnet_id     = aws_subnet.public-subnet-terraform-1.id

  tags = merge(local.common_tags, {
    Name = "terraform-nat-gateway"
  })
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

resource "aws_lb" "terraform-alb" {
  name               = "terraform-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.secgrp-alb.id]
  subnets            = [
    aws_subnet.public-subnet-terraform-1.id,
    aws_subnet.public-subnet-terraform-2.id
  ]

  enable_deletion_protection = false

  tags = merge(local.common_tags, {
    Name = "terraform-alb"
  })
}


resource "aws_lb_target_group" "terraform-alb-tg" {
  name     = "terraform-alb-tg"
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
    Name = "terraform-alb-tg"
  })
}

resource "aws_lb_listener" "app-lb-listener" {
  load_balancer_arn = aws_lb.terraform-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.terraform-alb-tg.arn
  }
}



resource "aws_instance" "web-server-1" {
  ami                         = "ami-01816d07b1128cd2d"
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
              sudo yum update -y
              sudo yum install -y nginx
              sudo systemctl start nginx
              sudo systemctl enable nginx
              echo "<html><body><h1>Hello from teraform web server 1!</h1><p>Public IP: $PUBLIC_IP</p><p>Private IP: $PRIVATE_IP</p></body></html>" | sudo tee /usr/share/nginx/html/index.html
              EOF

  tags = merge(local.common_tags, {
    Name = "terraform-web-server-1"
  })

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_lb.terraform-alb, aws_lb_target_group.terraform-alb-tg]
}

resource "aws_instance" "web-server-2" {
  ami                         = "ami-01816d07b1128cd2d"
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
              sudo yum update -y
              sudo yum install -y nginx
              sudo systemctl start nginx
              sudo systemctl enable nginx
              echo "<html><body><h1>Hello from teraform web server 2!</h1><p>Public IP: $PUBLIC_IP</p><p>Private IP: $PRIVATE_IP</p></body></html>" | sudo tee /usr/share/nginx/html/index.html
              EOF

  tags = merge(local.common_tags, {
    Name = "terraform-web-server-2"
  })

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_lb.terraform-alb, aws_lb_target_group.terraform-alb-tg]
}

resource "aws_lb_target_group_attachment" "web_server_1_attachment" {
  target_group_arn = aws_lb_target_group.terraform-alb-tg.arn
  target_id        = aws_instance.web-server-1.id
  port             = 80

  depends_on = [aws_instance.web-server-1]
}

resource "aws_lb_target_group_attachment" "web_server_2_attachment" {
  target_group_arn = aws_lb_target_group.terraform-alb-tg.arn
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
  value       = aws_lb.terraform-alb.dns_name
}
