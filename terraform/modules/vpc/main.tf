# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  
  # Enable DNS support - required for EKS
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# INTERNET GATEWAY
# -----------------------------------------------------------------------------
# Allows resources in public subnets to reach the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# SUBNETS
# Public subnets
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index)  # /20 subnets
  availability_zone = var.availability_zones[count.index]
  
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-${var.availability_zones[count.index]}"
    
    # tags are required for EKS to discover subnets for load balancers
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.name_prefix}-cluster" = "shared" # associates subnet with specific k8s cluster
  }
}

# Private subnets
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  # offset by 10 to avoid overlap with public subnets
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.name_prefix}-private-${var.availability_zones[count.index]}"
    
    "kubernetes.io/role/internal-elb"                  = "1"
    "kubernetes.io/cluster/${var.name_prefix}-cluster" = "shared"
  }
}

# ELASTIC IP
resource "aws_eip" "nat" {
  count  = 1
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT GATEWAY
resource "aws_nat_gateway" "main" {
  count = 1  # Single NAT for cost savings

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id  # NAT Gateway lives in public subnet

  tags = {
    Name = "${var.name_prefix}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# ROUTE TABLES
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # non-local traffic to Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # non-local traffic to NAT
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }

  tags = {
    Name = "${var.name_prefix}-private-rt"
  }
}

# ROUTE TABLE ASSOCIATIONS
resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}