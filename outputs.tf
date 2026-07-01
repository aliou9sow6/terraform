# Useful outputs to inspect after apply.
output "bucket_name" {
  description = "The name of the created S3 bucket."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "The ARN of the created S3 bucket."
  value       = aws_s3_bucket.this.arn
}

output "region" {
  description = "The AWS region used for this deployment."
  value       = var.aws_region
}

output "ec2_instance_id" {
  description = "The ID of the EC2 instance."
  value       = aws_instance.this.id
}

output "ec2_public_ip" {
  description = "The public IP address of the EC2 instance."
  value       = aws_instance.this.public_ip
}

output "ec2_instance_type" {
  description = "The instance type used for the EC2 instance."
  value       = aws_instance.this.instance_type
}

output "ebs_volume_id" {
  description = "The ID of the root EBS volume attached to the EC2 instance."
  value       = aws_instance.this.root_block_device[0].volume_id
}
