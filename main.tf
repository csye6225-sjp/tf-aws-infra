provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = var.vpc_name
  }
}

# Create Public Subnets
resource "aws_subnet" "public" {
  count = length(var.azs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = var.azs[count.index]

  tags = {
    Name = "Public-Subnet-${count.index}"
  }
}

# Create Private Subnets
resource "aws_subnet" "private" {
  count = length(var.azs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  map_public_ip_on_launch = false
  availability_zone       = var.azs[count.index]

  tags = {
    Name = "Private-Subnet-${count.index}"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Main-Internet-Gateway"
  }
}

# Create Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Public-Route-Table"
  }
}

# Create Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Private-Route-Table"
  }
}

# Add Public Route (0.0.0.0/0 -> IGW)
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public_association" {
  count = length(var.azs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private_association" {
  count = length(var.azs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Application Security Group for web application instances
resource "aws_security_group" "app_sg" {
  name        = "app-security-group"
  description = "Security group for web application instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow application traffic"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "App-Security-Group"
  }
}

# Database Security Group RDS instances
resource "aws_security_group" "db_sg" {
  name        = "db-security-group"
  description = "Security group for RDS, only allows inbound from app_sg"
  vpc_id      = aws_vpc.main.id

  # Ingress: only the application SG can access the DB port
  ingress {
    description     = "DB port from App SG"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  # Egress typically open
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "DB-Security-Group"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "mydb_subnet_group" {
  name       = "mydb-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "MyDBSubnetGroup"
  }
}

# DB Parameter Group
resource "aws_db_parameter_group" "mydb_params" {
  name        = "csye6225-db-params"
  family      = "postgres16" # or "mysql8.0", "mariadb10.5", etc.
  description = "Custom parameter group for CSYE6225"

  # Example parameter override
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }
}

# RDS Instance
resource "aws_db_instance" "mydb" {
  identifier             = "csye6225"
  engine                 = var.db_engine # "postgres", "mysql", "mariadb"
  engine_version         = "16"        # or version matching your engine
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.mydb_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false
  multi_az               = false
  db_name                = "csye6225" # DB name
  username               = var.db_user
  password               = var.db_password
  parameter_group_name   = aws_db_parameter_group.mydb_params.name

  skip_final_snapshot = true

  tags = {
    Name = "csye6225-RDS"
  }
}


# Generate a random UUID
resource "random_uuid" "s3" {}

resource "aws_s3_bucket" "attachments" {
  # Construct the bucket name using prefix + UUID
  bucket = "${var.s3_bucket_prefix}-${random_uuid.s3.result}"

  force_destroy = true
  acl           = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id      = "transition-to-standard-ia"
    enabled = true

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }

  tags = {
    Name        = "CSYE6225-Attachments-Bucket"
    Environment = "dev"
  }
}

data "aws_iam_policy_document" "allow_s3_bucket_access" {
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      # Possibly "s3:ListBucket" if you need to list objects
    ]
    resources = [
      aws_s3_bucket.attachments.arn,
      "${aws_s3_bucket.attachments.arn}/*"
    ]
    effect = "Allow"
  }
}

resource "aws_iam_policy" "s3_bucket_policy" {
  name        = "AllowS3BucketAccess"
  description = "Policy that allows read/write access to the S3 bucket"
  policy      = data.aws_iam_policy_document.allow_s3_bucket_access.json
}

resource "aws_iam_role" "ec2_s3_role" {
  name               = "EC2S3AccessRole"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    effect = "Allow"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_s3_attach" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.s3_bucket_policy.arn
}

resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "EC2S3InstanceProfile"
  role = aws_iam_role.ec2_s3_role.name
}


# EC2 Instance for your web application
resource "aws_instance" "app_instance" {
  ami           = var.custom_ami
  instance_type = "t2.micro"
  subnet_id     = element(aws_subnet.public.*.id, 0)

  key_name = null

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  root_block_device {
    volume_size           = 25
    volume_type           = "gp2"
    delete_on_termination = true
  }

  associate_public_ip_address = true
  disable_api_termination     = false

  # Associate the IAM Instance Profile so that the EC2 can access S3 without hardcoded credentials
  iam_instance_profile = aws_iam_instance_profile.ec2_s3_profile.name

  # Provide a user_data script that writes your DB/S3 environment variables at first boot
  user_data = <<-EOF
    #!/bin/bash
    
    echo "PORT=8080" >> /etc/csye6225.env
    echo "DB_HOST=${aws_db_instance.mydb.address}" >> /etc/csye6225.env
    echo "DB_USER=${var.db_user}" >> /etc/csye6225.env
    echo "DB_PASSWORD=${var.db_password}" >> /etc/csye6225.env
    echo "DB_NAME=csye6225" >> /etc/csye6225.env
    echo "S3_BUCKET=${aws_s3_bucket.attachments.bucket}" >> /etc/csye6225.env
    echo "AWS_REGION=${var.aws_region}" >> /etc/csye6225.env

    # Restrict read permissions for the env file
    chmod 600 /etc/csye6225.env

    # If desired, automatically start or enable your systemd service:
    # systemctl daemon-reload
    # systemctl enable csye6225.service
    # systemctl start csye6225.service
  EOF

  tags = {
    Name = "App-EC2-Instance"
  }
}
