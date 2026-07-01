# AWS Free Tier test project

This Terraform project creates a single S3 bucket in the configured AWS region to verify that a new AWS account can use the Free Tier safely without creating costly resources.

## What this project creates

Only the following resource is created:

- 1 S3 bucket
  - unique name generated with `random_id`
  - versioning disabled
  - SSE-S3 encryption enabled using AES256
  - public access blocked
  - tags applied via `local.common_tags`

No EC2, VPC, NAT Gateway, ALB, RDS, Lambda, CloudFront, Route53, EIP, or IAM users are created.

## Prerequisites

- Terraform 1.8 or newer
- AWS CLI configured with credentials, or AWS environment variables set
- An AWS account with permission to create S3 buckets

## Configure AWS credentials

If the AWS CLI is not installed yet, install it and configure it:

```bash
aws configure
```

You will be prompted for:

- AWS Access Key ID
- AWS Secret Access Key
- AWS region name
- output format

If you prefer environment variables:

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

On Windows PowerShell:

```powershell
$env:AWS_ACCESS_KEY_ID="your-access-key"
$env:AWS_SECRET_ACCESS_KEY="your-secret-key"
$env:AWS_DEFAULT_REGION="us-east-1"
```

## Usage

From this directory:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
terraform destroy
```

To customize settings, create a `terraform.tfvars` file and override variables such as `aws_region`, `project_name`, and `environment`.

## Verify the Free Tier behavior

After deployment, check the following in the AWS console:

- Billing
- Cost Explorer
- Free Tier

Confirm that the S3 bucket creation did not generate unexpected charges and that the account remains within expected Free Tier limits.

## Project structure

```text
aws-free-tier-test/
├── provider.tf
├── versions.tf
├── variables.tf
├── locals.tf
├── main.tf
├── outputs.tf
├── README.md
├── .gitignore
└── modules/
```

## Notes

- Tags are centralized in `locals.tf`.
- The bucket name is made unique with `random_id`.
- The configuration uses only Free Tier-compatible resources.
