terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC and networking
resource "aws_vpc" "clickhouse_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "clickhouse-vpc"
  }
}

resource "aws_internet_gateway" "clickhouse_igw" {
  vpc_id = aws_vpc.clickhouse_vpc.id

  tags = {
    Name = "clickhouse-igw"
  }
}

resource "aws_subnet" "clickhouse_subnet" {
  vpc_id                  = aws_vpc.clickhouse_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "clickhouse-subnet"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_route_table" "clickhouse_rt" {
  vpc_id = aws_vpc.clickhouse_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.clickhouse_igw.id
  }

  tags = {
    Name = "clickhouse-rt"
  }
}

resource "aws_route_table_association" "clickhouse_rta" {
  subnet_id      = aws_subnet.clickhouse_subnet.id
  route_table_id = aws_route_table.clickhouse_rt.id
}

# Security Group
resource "aws_security_group" "clickhouse_sg" {
  name        = "clickhouse-security-group"
  description = "Security group for ClickHouse server"
  vpc_id      = aws_vpc.clickhouse_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # ClickHouse HTTP interface
  ingress {
    from_port   = 8123
    to_port     = 8123
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # ClickHouse native TCP interface
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "clickhouse-sg"
  }
}

# User data script to run ClickHouse
resource "random_password" "clickhouse_password" {
  length  = 16
  special = true
}

locals {
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    clickhouse_password = random_password.clickhouse_password.result
  }))
}

# EC2 Instance
resource "aws_key_pair" "generated" {
  key_name   = "ec2-clickhouse"
  public_key = file("${path.module}/ec2-clickhouse.pub")
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_instance" "clickhouse_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.generated.key_name
  vpc_security_group_ids      = [aws_security_group.clickhouse_sg.id]
  subnet_id                   = aws_subnet.clickhouse_subnet.id
  associate_public_ip_address = true
  user_data                   = local.user_data

  root_block_device {
    volume_type = "gp3"
    volume_size = var.volume_size
    encrypted   = true
  }

  tags = {
    Name = "clickhouse-server"
  }
}