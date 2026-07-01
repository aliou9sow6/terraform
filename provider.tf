# Provider configuration for the AWS free-tier validation project.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
