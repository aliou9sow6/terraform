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
