locals {
  # Storage environments are independent of Kubernetes namespaces and cluster inputs.
  application_namespace_keys = toset(["stage", "prod"])

  s3_bucket_suffix    = "${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  s3_bucket_base_name = endswith(var.s3_bucket_name, "-${local.s3_bucket_suffix}") ? var.s3_bucket_name : "${var.s3_bucket_name}-${local.s3_bucket_suffix}"

  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}
