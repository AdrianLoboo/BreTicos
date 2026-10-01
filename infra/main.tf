terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "breticos" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "breticos-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.breticos.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "breticos-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.breticos.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "breticos-public-b"
  }
}

resource "aws_internet_gateway" "breticos" {
  vpc_id = aws_vpc.breticos.id

  tags = {
    Name = "breticos-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.breticos.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.breticos.id
  }

  tags = {
    Name = "breticos-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.breticos.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "breticos-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.breticos.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "breticos-private-b"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.breticos.id

  tags = {
    Name = "breticos-private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb" {
  name        = "breticos-alb-sg"
  description = "Security group for Breticos Application Load Balancer"
  vpc_id      = aws_vpc.breticos.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "breticos-alb-sg"
  }
}

resource "aws_security_group" "backend" {
  name        = "breticos-backend-sg"
  description = "Security group for Breticos backend"
  vpc_id      = aws_vpc.breticos.id

  ingress {
    description     = "Backend traffic from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "breticos-backend-sg"
  }
}

resource "aws_security_group" "database" {
  name        = "breticos-database-sg"
  description = "Security group for Breticos database"
  vpc_id      = aws_vpc.breticos.id

  ingress {
    description     = "PostgreSQL from backend"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "breticos-database-sg"
  }
}

resource "aws_lb" "breticos" {
  name               = "breticos-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  tags = {
    Name = "breticos-alb"
  }
}

resource "aws_lb_target_group" "backend" {
  name        = "breticos-backend-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.breticos.id

  health_check {
    enabled  = true
    path     = "/health"
    protocol = "HTTP"
    port     = "traffic-port"
  }

  tags = {
    Name = "breticos-backend-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.breticos.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

resource "aws_db_subnet_group" "breticos" {
  name = "breticos-db-subnet-group"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  tags = {
    Name = "breticos-db-subnet-group"
  }
}

resource "aws_db_instance" "breticos" {
  identifier = "breticos-db"

  engine         = "postgres"
  engine_version = "17"

  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "breticos"
  username = "breticos_admin"
  password = "var.db_password"

  db_subnet_group_name = aws_db_subnet_group.breticos.name
  vpc_security_group_ids = [
    aws_security_group.database.id
  ]

  publicly_accessible = false
  multi_az            = false
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "breticos-db"
  }
}