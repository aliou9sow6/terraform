# Input variables used to customize the deployment without changing the code.
variable "aws_region" {
  description = "AWS region where the free-tier test resources will be created."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Base name used to identify the project and build the bucket name."
  type        = string
  default     = "aws-free-tier-test"
}

variable "environment" {
  description = "Deployment environment label used for resource naming and tags."
  type        = string
  default     = "dev"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance. Defaults to Amazon Linux 2023 in us-east-1 (free tier eligible)."
  type        = string
  default     = "ami-0c02fb55956c7d316" # Amazon Linux 2023 - us-east-1
}

variable "instance_type" {
  description = "EC2 instance type. t2.micro is free tier eligible."
  type        = string
  default     = "t2.micro"
}

variable "ebs_volume_size" {
  description = "Size of the EBS volume in GB. Free tier includes up to 30 GB."
  type        = number
  default     = 8
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH into the EC2 instance. Restrict to your IP in production."
  type        = string
  default     = "0.0.0.0/0"
}
