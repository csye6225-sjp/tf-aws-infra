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
  #removing this for adding load balancer 
  # ingress {
  #   description = "Allow HTTP"
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # ingress {
  #   description = "Allow HTTPS"
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  ingress {
    description     = "Allow application traffic"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
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
# Security group for the Load Balancer
resource "aws_security_group" "lb_sg" {
  name        = "lb-security-group"
  description = "Security group for the Application Load Balancer"
  vpc_id      = aws_vpc.main.id

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

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "LB-Security-Group"
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
  engine_version         = "16"          # or version matching your engine
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.mydb_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false
  multi_az               = false
  db_name                = "csye6225" # DB name
  username               = var.db_user
  password               = random_password.db_password.result
  parameter_group_name   = aws_db_parameter_group.mydb_params.name
  kms_key_id             = aws_kms_key.rds_key.arn
  storage_encrypted      = true




  skip_final_snapshot = true

  tags = {
    Name = "csye6225-RDS"
  }
}

# Auto-generate password
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Store in Secrets Manager using custom KMS key
resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "csye6225-db-password"
  kms_key_id              = aws_kms_key.secrets_key.arn
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_secret_value" {
  secret_id     = aws_secretsmanager_secret.db_secret.id
  secret_string = random_password.db_password.result
}
# EC2 IAM Role Policy for accessing secrets


# Attach the policy to the EC2 instance role


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
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.s3_key.arn
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
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
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


resource "aws_iam_policy" "secrets_access_policy" {
  name = "AllowReadCSYE6225Secret"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = aws_secretsmanager_secret.db_secret.arn
      },
      {
        Sid    = "KMSDecryptAccess",
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = aws_kms_key.secrets_key.arn
      }
    ]
  })
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

resource "aws_iam_role" "ec2_role" {
  name               = "EC2CombinedRole"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# CloudWatch Agent policy
resource "aws_iam_policy" "cloudwatch_agent_policy" {
  name        = "CloudWatchAgentPolicy"
  description = "Policy for CloudWatch Agent to send logs and metrics"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:PutMetricData"
        ],
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_policy" "ec2_kms_s3_policy" {
  name = "EC2S3KMSAccess"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:GenerateDataKey",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource = aws_kms_key.s3_key.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ec2_kms_s3_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_kms_s3_policy.arn
}


resource "aws_iam_role_policy_attachment" "s3_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_bucket_policy.arn
}

resource "aws_iam_role_policy_attachment" "cw_agent_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.cloudwatch_agent_policy.arn
}
resource "aws_iam_role_policy_attachment" "attach_secrets_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets_access_policy.arn
}


resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2CombinedInstanceProfile"
  role = aws_iam_role.ec2_role.name
}


resource "aws_launch_template" "webapp_lt" {
  name_prefix   = "csye6225-webapp-"
  image_id      = var.custom_ami
  instance_type = var.instance_type
  key_name      = var.aws_key_name
  # associate_public_ip_address = true

  user_data = base64encode(<<-EOF
    #!/bin/bash

    sudo snap install aws-cli --classic
    echo "PORT=8080" >> /etc/csye6225.env
    echo "DB_HOST=${aws_db_instance.mydb.address}" >> /etc/csye6225.env
    echo "DB_USER=${var.db_user}" >> /etc/csye6225.env
    DB_PASSWORD=$(aws secretsmanager get-secret-value \
      --secret-id csye6225-db-password \
      --query SecretString \
      --output text \
      --region ${var.aws_region})
    echo "DB_PASSWORD=$DB_PASSWORD" >> /etc/csye6225.env
    echo "DB_NAME=csye6225" >> /etc/csye6225.env
    echo "S3_BUCKET=${aws_s3_bucket.attachments.bucket}" >> /etc/csye6225.env
    echo "AWS_REGION=${var.aws_region}" >> /etc/csye6225.env

    # Ensure log file exists
    touch /var/log/webapp.log
    chown csye6225:csye6225 /var/log/webapp.log

    # Start CloudWatch Agent (assuming config is already in the AMI)
    sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
         -a fetch-config -m ec2 -c file:/opt/cloudwatch-agent-config.json -s

    # Start the application
    /usr/bin/node /opt/csye6225/webapp/src/server.js
  EOF
  )
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 25
      volume_type           = "gp2"
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = aws_kms_key.ec2_key.arn
    }
  }


  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    device_index                = 0
    associate_public_ip_address = true
    security_groups             = [aws_security_group.app_sg.id]
  }


  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "CSYE6225-Webapp-LaunchTemplate"
  }
}

# ======================================
# Auto Scaling Group for Web Application
# ======================================
resource "aws_autoscaling_group" "webapp_asg" {
  name             = "csye6225_asg1"
  desired_capacity = 1
  min_size         = 1
  max_size         = 5
  # Temporarily use public subnets for SSH access
  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.webapp_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "CSYE6225-Webapp"
    propagate_at_launch = true
  }

  tag {
    key                 = "AutoScalingGroup"
    value               = "csye6225_asg"
    propagate_at_launch = true
  }

  target_group_arns = [aws_lb_target_group.webapp_tg.arn]

  lifecycle {
    create_before_destroy = true
  }
}

# ======================================
# Auto Scaling Policies & CloudWatch Alarms
# ======================================
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "csye6225_scale_up"
  autoscaling_group_name = aws_autoscaling_group.webapp_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 60
  policy_type            = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "csye6225_scale_down"
  autoscaling_group_name = aws_autoscaling_group.webapp_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 60
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm_high" {
  alarm_name          = "csye6225_cpu_high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 10
  alarm_description   = "Scale up if CPU > 5%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm_low" {
  alarm_name          = "csye6225_cpu_low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 3
  alarm_description   = "Scale down if CPU < 3%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
}

# ======================================
# Application Load Balancer (ALB)
# ======================================
resource "aws_lb" "webapp_alb" {
  name               = "csye6225-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "CSYE6225-ALB"
  }
}

resource "aws_lb_target_group" "webapp_tg" {
  name     = "csye6225-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/healthz"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "CSYE6225-TG"
  }
}

resource "aws_lb_listener" "webapp_listener" {
  load_balancer_arn = aws_lb.webapp_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  certificate_arn = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webapp_tg.arn
  }
}

# ======================================
# Route53 DNS Record for the ALB
# ======================================
resource "aws_route53_record" "webapp_alias" {
  zone_id = var.route53_zone_id # Hosted Zone ID for your (dev|demo).sahanajprakash.me
  name    = var.domain_name     # e.g., "dev.sahanajprakash.me" or "demo.sahanajprakash.me"
  type    = "A"

  alias {
    name                   = aws_lb.webapp_alb.dns_name
    zone_id                = aws_lb.webapp_alb.zone_id
    evaluate_target_health = true
  }
}
# EC2 Instance for your web application
# resource "aws_instance" "app_instance" {
#   ami           = var.custom_ami
#   instance_type = "t2.micro"
#   subnet_id     = element(aws_subnet.public.*.id, 0)

#   key_name = null

#   vpc_security_group_ids = [aws_security_group.app_sg.id]

#   root_block_device {
#     volume_size           = 25
#     volume_type           = "gp2"
#     delete_on_termination = true
#   }

#   associate_public_ip_address = true
#   disable_api_termination     = false

#   # Associate the IAM Instance Profile so that the EC2 can access S3 and cloudwatch without hardcoded credentials
#   iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

#   # Provide a user_data script that writes your DB/S3 environment variables at first boot
#   user_data = <<-EOF
#     #!/bin/bash

#     echo "PORT=8080" >> /etc/csye6225.env
#     echo "DB_HOST=${aws_db_instance.mydb.address}" >> /etc/csye6225.env
#     echo "DB_USER=${var.db_user}" >> /etc/csye6225.env
#     echo "DB_PASSWORD=${var.db_password}" >> /etc/csye6225.env
#     echo "DB_NAME=csye6225" >> /etc/csye6225.env
#     echo "S3_BUCKET=${aws_s3_bucket.attachments.bucket}" >> /etc/csye6225.env
#     echo "AWS_REGION=${var.aws_region}" >> /etc/csye6225.env
#     sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/cloudwatch-agent-config.json -s
#     # Restrict read permissions for the env file
#     chmod 600 /etc/csye6225.env

#   EOF

#   tags = {
#     Name = "App-EC2-Instance"
#   }
# }
