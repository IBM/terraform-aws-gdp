##############################################
# Shared Auto VPC Module for Guardium GDP
##############################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "region" {
  description = "AWS region"
  type        = string
}

# =====================================================
# 1️⃣ Create VPC + IGW + Route Table (if not exists)
# =====================================================
resource "aws_vpc" "auto_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "guardium-auto-vpc" }
}

resource "aws_internet_gateway" "auto_igw" {
  vpc_id = aws_vpc.auto_vpc.id
  tags   = { Name = "guardium-auto-igw" }
}

resource "aws_route_table" "auto_rt" {
  vpc_id = aws_vpc.auto_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.auto_igw.id
  }

  tags = { Name = "guardium-auto-rt" }
}

# =====================================================
# 2️⃣ Subnets for each Guardium component
# =====================================================
resource "aws_subnet" "cm_subnet" {
  vpc_id                  = aws_vpc.auto_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "guardium-cm-subnet" }
}

resource "aws_subnet" "agg_subnet" {
  vpc_id                  = aws_vpc.auto_vpc.id
  cidr_block              = "10.0.4.0/22"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "guardium-agg-subnet" }
}

resource "aws_subnet" "col_subnet" {
  vpc_id                  = aws_vpc.auto_vpc.id
  cidr_block              = "10.0.8.0/22"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "guardium-col-subnet" }
}

# =====================================================
# 3️⃣ Associate all subnets with route table
# =====================================================
resource "aws_route_table_association" "cm_rta" {
  subnet_id      = aws_subnet.cm_subnet.id
  route_table_id = aws_route_table.auto_rt.id
}

resource "aws_route_table_association" "agg_rta" {
  subnet_id      = aws_subnet.agg_subnet.id
  route_table_id = aws_route_table.auto_rt.id
}

resource "aws_route_table_association" "col_rta" {
  subnet_id      = aws_subnet.col_subnet.id
  route_table_id = aws_route_table.auto_rt.id
}

# =====================================================
# 4️⃣ Outputs
# =====================================================
output "vpc_id" {
  description = "Shared Guardium auto-created VPC ID"
  value       = aws_vpc.auto_vpc.id
}

output "route_table_id" {
  description = "Main route table ID used by all Guardium subnets"
  value       = aws_route_table.auto_rt.id
}

output "subnet_cm_id" {
  description = "Subnet ID for Central Manager"
  value       = aws_subnet.cm_subnet.id
}

output "subnet_agg_id" {
  description = "Subnet ID for Aggregator"
  value       = aws_subnet.agg_subnet.id
}

output "subnet_col_id" {
  description = "Subnet ID for Collector"
  value       = aws_subnet.col_subnet.id
}

