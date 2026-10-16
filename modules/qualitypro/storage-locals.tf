locals {
  s3_bucket_suffix    = "${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  s3_bucket_base_name = endswith(var.s3_bucket_name, "-${local.s3_bucket_suffix}") ? var.s3_bucket_name : "${var.s3_bucket_name}-${local.s3_bucket_suffix}"
  storage_bucket_arns = { for namespace, bucket in aws_s3_bucket.backend : namespace => bucket.arn }

  project_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}
