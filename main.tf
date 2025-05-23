terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = "mi-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"] 
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway  = false

  tags = {
    Terraform = "true"
    Environment = "dev"

  }
}

resource "aws_security_group" "sg_ec2" {
  name        = "ec2-security-group"
  description = "Permite trafico desde el balanceador de carga"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 80 
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_lb.id] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name = "ec2-security-group"
    Terraform = "true"
  }
}

resource "aws_instance" "ec2_test" {
  count         = 2 
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = module.vpc.private_subnets[count.index]
  vpc_security_group_ids = [aws_security_group.sg_ec2.id]

  # Waiting for Nat Gateway to avoid http installation error
  depends_on = [
    module.vpc
  ]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || echo "")
              INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id || echo "")
              PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4 || echo "")
              echo "<html><body><h1>Hola Mundo!!</h1><h2>Instance: $INSTANCE_ID, IP: $PRIVATE_IP</h2></body></html>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "ec2_test-${count.index + 1}"
    Terraform = "true"
  }
}

resource "aws_security_group" "sg_lb" {
  name        = "lb-security-group"
  description = "Permite trafico HTTP entrante"
  vpc_id      = module.vpc.vpc_id

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

  tags = {
    Name = "lb-security-group"
    Terraform = "true"
  }
}

resource "aws_elb" "test_lb" {
  name               = "test-lb"
  security_groups    = [aws_security_group.sg_lb.id]

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:80/index.html"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  instances = aws_instance.ec2_test[*].id

  subnets = module.vpc.public_subnets

  tags = {
    Name = "test-lb"
    Terraform = "true"
  }
}

# Output to get the DNS name of the load balancer
output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_elb.test_lb.dns_name
}