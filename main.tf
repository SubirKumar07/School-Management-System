# Configure AWS Provider
provider "aws" {
  region = "us-east-1" # Replace with your desired region
}

# Create VPC
resource "aws_vpc" "school_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create an internet gateway for the VPC
resource "aws_internet_gateway" "school_gateway" {
  vpc_id = aws_vpc.school_vpc.id
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.school_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a" # Update for each availability zone
}

# Create a route table for the public subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.school_vpc.id
}

# Create a route to the internet gateway
resource "aws_route" "public_route" {
  route_table_id = aws_route_table.public_route_table.id
  gateway_id     = aws_internet_gateway.school_gateway.id
  destination_cidr_block = "0.0.0.0/0"
}

# Associate the public subnet with the route table
resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Create a security group for the web server
resource "aws_security_group" "web_server_sg" {
  name = "web_server_sg"
  vpc_id = aws_vpc.school_vpc.id

  ingress {
    from_port = 80
    to_port   = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Update to restrict access if needed
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an Aurora database cluster
resource "aws_rds_cluster" "school_db" {
  engine         = "aurora-mysql"
  cluster_identifier = "school-db-cluster"
  database_name     = "<your_database_name>"
  master_username   = "<your_database_username>"
  master_password   = "<your_database_password>"
  allocated_storage = 20

  vpc_security_group_ids = [aws_security_group.web_server_sg.id]
}

# Create an S3 bucket for storing images
resource "aws_s3_bucket" "school_images" {
  bucket = "<your_s3_bucket_name>"
  acl    = "private"
}

# IAM Role for the Lambda function (replace with your specific policies)
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# IAM policy for the Lambda function (replace with your specific permissions)
resource "aws_iam_policy" "lambda_policy" {
  name = "lambda_policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "
