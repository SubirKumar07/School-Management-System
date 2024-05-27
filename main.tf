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
  database_name        = "school_database"  # Replace with your desired database name
  master_username       = "school_admin"     # Replace with a strong username
  master_password       = var.db_password   # Reference a secure password stored in a variable
  deletion_protection  = false             # Optional: Set to true to prevent accidental deletion

  # VPC settings (replace with your subnet IDs)
  vpc_security_group_ids = [
    aws_security_group.web_server_sg.id  # Allow access from web server instances
  ]
  db_subnet_group_name = "school_db_subnet_group"

  # Create a DB subnet group for the database cluster
  resource "aws_db_subnet_group" "school_db_subnet_group" {
    name = "school_db_subnet_group"
    description = "Subnet group for the school database cluster"

    subnet_ids = [
      aws_subnet.private_subnet.id,  # Add subnets from different availability zones for redundancy
    ]
  }
}



# Create S3 Buckets
resource "aws_s3_bucket" "source_images" {
  bucket = "school-source-images"
  acl    = "private"

  # Enable versioning for historical backups
  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket" "compressed_images" {
  bucket = "school-compressed-images"
  acl    = "private"
}

# IAM Role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "school_lambda_role"

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

# IAM Policy for Lambda function (Grants access to S3 buckets)
resource "aws_iam_policy" "lambda_policy" {
  name = "school_lambda_policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::school-source-images/*",
        "arn:aws:s3:::school-compressed-images/*"
      ]
    }
  ]
}
EOF
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lambda_role_attachment" {
  role       = aws_iam_role.lambda_role.id
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Lambda function for image compression (Replace with your actual code)
resource "aws_lambda_function" "image_compressor" {
  filename = "image_compressor.py" # Replace with your Python script path
  handler  = "image_compressor.handler"
  runtime  = "python3.9"
  role     = aws_iam_role.lambda_role.arn

  # Trigger the function when a new object is uploaded to the source bucket
  environment {
    variables = {
      SOURCE_BUCKET = aws_s3_bucket.source_images.arn
      DEST_BUCKET   = aws_s3_bucket.compressed_images.arn
    }
  }

  # Set up an S3 event notification for the source bucket
  resource "aws_lambda_event_source_mapping" "s3_event" {
    event_source_arn = aws_s3_bucket.source_images.arn
    function_arn     = aws_lambda_function.image_compressor.arn
    # Only trigger on object creation events
    filters = {
      "Type" = "ObjectCreated"
    }
  }
}
