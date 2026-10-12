# Publish non-secret metadata through AWS so consumers do not need HCP state access.
resource "aws_ssm_parameter" "storage" {
  name        = "/qualitypro/${var.project_name}/storage"
  description = "Stage/prod S3 bucket metadata for the ${var.project_name} project."
  type        = "String"
  tier        = "Standard"

  insecure_value = jsonencode({
    schema_version = 1
    aws_account_id = data.aws_caller_identity.current.account_id
    aws_region     = var.aws_region
    s3_bucket_name = { for namespace, bucket in aws_s3_bucket.backend : namespace => bucket.id }
    s3_bucket_arn  = { for namespace, bucket in aws_s3_bucket.backend : namespace => bucket.arn }
  })

  depends_on = [
    aws_s3_bucket_public_access_block.backend,
    aws_s3_bucket_server_side_encryption_configuration.backend,
    aws_s3_bucket_versioning.backend,
  ]
}
