# Network layer: VPC, web/app/db subnets, and firewall rules (security groups).
# Traffic path: internet -> web -> app -> database. Nothing skips a tier.

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name_prefix}-vpc" }
}

resource "aws_subnet" "web" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.web_subnet_cidr
  availability_zone = var.availability_zones[0]
  tags              = { Name = "${var.name_prefix}-web" }
}

resource "aws_subnet" "app" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.app_subnet_cidr
  availability_zone = var.availability_zones[0]
  tags              = { Name = "${var.name_prefix}-app" }
}

# A managed database needs subnets in two zones, so there are two.
resource "aws_subnet" "db" {
  count             = length(var.db_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.db_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  tags              = { Name = "${var.name_prefix}-db-${count.index}" }
}

resource "aws_security_group" "web" {
  name   = "${var.name_prefix}-web"
  vpc_id = aws_vpc.this.id

  ingress {
    description = "HTTPS from allowed sources"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.web_source_ranges
  }

  egress {
    description = "Only to the app subnet"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [var.app_subnet_cidr]
  }
}

resource "aws_security_group" "app" {
  name   = "${var.name_prefix}-app"
  vpc_id = aws_vpc.this.id

  ingress {
    description     = "App port from the web tier only"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    description = "Only inside the VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
}

resource "aws_security_group" "db" {
  name   = "${var.name_prefix}-db"
  vpc_id = aws_vpc.this.id

  ingress {
    description     = "Database port from the app tier only"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
}
