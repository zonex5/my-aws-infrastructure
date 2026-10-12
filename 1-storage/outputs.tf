output "s3_bucket_name" {
  description = "Backend S3 bucket names keyed by application environment."
  value       = { for namespace, bucket in aws_s3_bucket.backend : namespace => bucket.id }
}

output "s3_bucket_arn" {
  description = "Backend S3 bucket ARNs keyed by application environment, consumed by infrastructure IAM policies."
  value       = { for namespace, bucket in aws_s3_bucket.backend : namespace => bucket.arn }
}

output "aws_account_id" {
  description = "AWS account owning storage; infrastructure verifies this before using the bucket ARNs."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "Storage region; infrastructure verifies that its region matches."
  value       = var.aws_region
}

output "storage_metadata_parameter_name" {
  description = "SSM parameter automatically publishing bucket metadata for infrastructure."
  value       = aws_ssm_parameter.storage.name
}
