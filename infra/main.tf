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