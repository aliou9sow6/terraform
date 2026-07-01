# Local values centralize naming and tagging rules for all AWS resources.
locals {
  name_prefix = substr(replace(replace(replace(replace(lower(var.project_name), " ", "-"), "_", "-"), ".", "-"), "/", "-"), 0, 24)
  env_prefix  = substr(replace(replace(replace(replace(lower(var.environment), " ", "-"), "_", "-"), ".", "-"), "/", "-"), 0, 8)
  bucket_name = "${local.name_prefix}-${local.env_prefix}-${random_id.bucket_suffix.hex}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "FreeTierValidation"
  }
}
