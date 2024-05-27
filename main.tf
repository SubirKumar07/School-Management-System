# Configure AWS Provider
provider "aws" {
  region = "us-east-1" # Replace with your desired region
}

# Create VPC
resource "aws_vpc" "school_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create Internet Gateway
resource "aws_internet_gateway" "school_gateway" {
  vpc_id = aws_vpc.school_vpc.id
}

# Create Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.school_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  # Enable auto-assign public IP addresses
  map_public_ip_on_launch = true
}

# Create Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.school_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

# Create Route Table for Public Subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.school_vpc.id
}

# Create Route for Public Subnet
resource "aws_route" "public_route" {
  route_table_id = aws_route_table.public_route_table.id
  cidr_block     = "0.0.0.0/0"
  gateway_id     = aws_internet_gateway.school_gateway.id
}

# Create Route Table for Private Subnet (no internet access)
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.school_vpc.id
}

# Create Route for Private Subnet (connects to NAT Gateway later)
resource "aws_route" "private_route" {
  route_table_id = aws_route_table.private_route_table.id
  cidr_block     = "0.0.0.0/0"
}

# Create NAT Gateway (for private subnet instances to access internet)
resource "aws_nat_gateway" "school_nat_gateway" {
  subnet_id = aws_subnet.public_subnet.id

  # Allocate an elastic IP address
  allocation_id = aws_eip.nat_gateway_eip.id
}

# Create Elastic IP for NAT Gateway
resource "aws_eip" "nat_gateway_eip" {
  depends_on = [aws_internet_gateway.school_gateway]

  allocation_id = aws_internet_gateway.school_gateway.public_ip

  # Associate the IP with the NAT Gateway
  association_id = aws_nat_gateway.school_nat_gateway.id
}

# Create Security Groups (add specific rules based on your needs)
resource "aws_security_group" "web_server_sg" {
  name        = "web_server_sg"
  vpc_id      = aws_vpc.school_vpc.id
  description = "Security group for web server instances"

  # Allow inbound HTTP traffic from anywhere
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH access from your IP address
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["your_public_ip/32"]
  }
}

# ... (add resources for database, Lambda function, S3 buckets, etc.)

# Example: Create an Aurora MySQL database

resource "aws_rds_cluster" "school_db" {
  engine                = "aurora-mysql"
  engine_version        = "5.7.12"
  db_cluster_parameter_group_name = "default-aurora-cluster-parameter-group"
  allocated_storage    = 20
  database_name        = "school_
