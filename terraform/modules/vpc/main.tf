# terraform/modules/vpc/main.tf

# -------------------------------------------------------------------
# VPC
# -------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true      # required for EKS
  enable_dns_hostnames = true      # required for EKS

  tags = {
    Name = "${var.project_name}-vpc"
    # EKS needs these tags to discover the VPC
    "kubernetes.io/cluster/${var.project_name}-cluster" = "shared"
  }
}

# -------------------------------------------------------------------
# INTERNET GATEWAY — allows public subnets to reach the internet
# -------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# -------------------------------------------------------------------
# PUBLIC SUBNETS — one per AZ
# ALB and NAT Gateways live here
# -------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true   # instances in public subnets get public IPs

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    # Required tag for AWS Load Balancer Controller to discover public subnets
    "kubernetes.io/role/elb"                                        = "1"
    "kubernetes.io/cluster/${var.project_name}-cluster"             = "shared"
  }
}

# -------------------------------------------------------------------
# PRIVATE SUBNETS — one per AZ
# EKS worker nodes live here — never directly internet-accessible
# -------------------------------------------------------------------
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    # Required tag for AWS Load Balancer Controller to discover private subnets
    "kubernetes.io/role/internal-elb"                               = "1"
    "kubernetes.io/cluster/${var.project_name}-cluster"             = "shared"
  }
}

# -------------------------------------------------------------------
# ELASTIC IPs for NAT Gateways (one per AZ for high availability)
# -------------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# -------------------------------------------------------------------
# NAT GATEWAYS — one per public subnet (one per AZ)
# Allows private subnet nodes to reach the internet (ECR image pulls)
# without being publicly addressable themselves
# -------------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  count = length(var.public_subnet_cidrs)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-nat-gw-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# -------------------------------------------------------------------
# ROUTE TABLE — public subnets
# All traffic (0.0.0.0/0) routes to the Internet Gateway
# -------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -------------------------------------------------------------------
# ROUTE TABLES — private subnets (one per AZ)
# Each private subnet routes outbound traffic through its AZ's
# NAT Gateway — if one NAT goes down, only that AZ is affected
# -------------------------------------------------------------------
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}