variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "vpc_name" {
  description = "VPC Name"
  type        = string
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "app_port" {
  description = "The port on which the application runs"
  type        = number
  default     = 8080
}

variable "custom_ami" {
  description = "Custom AMI ID for the EC2 instance"
  type        = string
}

variable "aws_key_name" {
  description = "AWS key pair name to associate with the instance (optional)"
  type        = string
  default     = ""
}

variable "s3_bucket_prefix" {
  type    = string
  default = "csye6225"
}

variable "db_user" {
  type        = string
  description = "Username for the RDS database"
  default     = "csye6225"
}

variable "db_password" {
  type        = string
  description = "Password for the RDS database"
  # for security, do NOT give a default; pass via tfvars or environment
}
variable "db_engine" {
  type        = string
  description = "RDS engine type (postgres, mysql, mariadb)"
  default     = "postgres"
}

variable "db_port" {
  type        = number
  description = "Database port (5432 for Postgres, 3306 for MySQL/MariaDB)"
  default     = 5432
}

variable "instance_type" {
  description = "EC2 instance type for Auto Scaling (e.g., t2.micro)"
  type        = string
  default     = "t2.micro"
}

variable "route53_zone_id" {
  description = "The ID of the Route53 hosted zone for your domain (e.g., dev.sahanajprakash.me)"
  type        = string
}

variable "domain_name" {
  description = "The domain name to be used in the Route53 record (e.g., dev.sahanajprakash.me or demo.sahanajprakash.me)"
  type        = string
}
