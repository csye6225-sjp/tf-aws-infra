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

