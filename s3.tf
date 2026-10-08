resource "aws_s3_bucket" "backend" {
  for_each = local.application_namespace_keys

  bucket = "${each.key}-${local.s3_bucket_base_name}"

  tags = local.common_tags

  lifecycle {
    precondition {
      condition     = length("${each.key}-${local.s3_bucket_base_name}") <= 63
      error_message = "The generated <namespace>-<s3_bucket_name>-<account-id>-<region> bucket name must be at most 63 characters; shorten s3_bucket_name."
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backend" {
  for_each = local.application_namespace_keys

  bucket = aws_s3_bucket.backend[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backend" {
  for_each = local.application_namespace_keys

  bucket = aws_s3_bucket.backend[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "backend" {
  for_each = local.application_namespace_keys

  bucket = aws_s3_bucket.backend[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}
