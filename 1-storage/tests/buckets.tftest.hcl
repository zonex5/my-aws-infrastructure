mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
}

variables {
  aws_region     = "us-east-1"
  project_name   = "cluster-1"
  s3_bucket_name = "test-docs"
}

override_resource {
  target          = aws_s3_bucket.backend["stage"]
  override_during = plan
  values = {
    id  = "stage-test-docs-123456789012-us-east-1"
    arn = "arn:aws:s3:::stage-test-docs-123456789012-us-east-1"
  }
}

override_resource {
  target          = aws_s3_bucket.backend["prod"]
  override_during = plan
  values = {
    id  = "prod-test-docs-123456789012-us-east-1"
    arn = "arn:aws:s3:::prod-test-docs-123456789012-us-east-1"
  }
}

run "isolated_private_encrypted_versioned_buckets" {
  command = plan

  assert {
    condition = (
      toset(keys(aws_s3_bucket.backend)) == toset(["stage", "prod"]) &&
      alltrue([
        for namespace in ["stage", "prod"] :
        aws_s3_bucket.backend[namespace].bucket == "${namespace}-test-docs-123456789012-us-east-1" &&
        !aws_s3_bucket.backend[namespace].force_destroy &&
        aws_s3_bucket.backend[namespace].tags.Project == "cluster-1" &&
        aws_s3_bucket_public_access_block.backend[namespace].bucket == aws_s3_bucket.backend[namespace].id &&
        aws_s3_bucket_public_access_block.backend[namespace].block_public_acls &&
        aws_s3_bucket_public_access_block.backend[namespace].block_public_policy &&
        aws_s3_bucket_public_access_block.backend[namespace].ignore_public_acls &&
        aws_s3_bucket_public_access_block.backend[namespace].restrict_public_buckets &&
        aws_s3_bucket_server_side_encryption_configuration.backend[namespace].bucket == aws_s3_bucket.backend[namespace].id &&
        one(one(aws_s3_bucket_server_side_encryption_configuration.backend[namespace].rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256" &&
        aws_s3_bucket_versioning.backend[namespace].bucket == aws_s3_bucket.backend[namespace].id &&
        one(aws_s3_bucket_versioning.backend[namespace].versioning_configuration).status == "Enabled" &&
        output.s3_bucket_name[namespace] == "${namespace}-test-docs-123456789012-us-east-1" &&
        output.s3_bucket_arn[namespace] == "arn:aws:s3:::${namespace}-test-docs-123456789012-us-east-1"
      ]) &&
      output.aws_account_id == "123456789012" &&
      output.aws_region == "us-east-1"
    )
    error_message = "Storage must create private, AES256-encrypted, versioned stage/prod buckets and publish their identities independently of a cluster."
  }

  assert {
    condition = (
      aws_ssm_parameter.storage.name == "/qualitypro/cluster-1/storage" &&
      aws_ssm_parameter.storage.type == "String" &&
      aws_ssm_parameter.storage.tier == "Standard" &&
      output.storage_metadata_parameter_name == "/qualitypro/cluster-1/storage" &&
      jsondecode(aws_ssm_parameter.storage.insecure_value) == {
        schema_version = 1
        aws_account_id = output.aws_account_id
        aws_region     = output.aws_region
        s3_bucket_name = output.s3_bucket_name
        s3_bucket_arn  = output.s3_bucket_arn
      }
    )
    error_message = "Storage must automatically publish its actual bucket names and ARNs at the shared project SSM path."
  }
}

run "bucket_suffix_already_present" {
  command = plan

  variables {
    s3_bucket_name = "test-docs-123456789012-us-east-1"
  }

  assert {
    condition = alltrue([
      for namespace in ["stage", "prod"] :
      aws_s3_bucket.backend[namespace].bucket == "${namespace}-test-docs-123456789012-us-east-1"
    ])
    error_message = "The current account/region suffix must not be appended twice."
  }
}

run "bucket_name_at_limit" {
  command = plan

  variables {
    s3_bucket_name = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  }

  assert {
    condition     = length(aws_s3_bucket.backend["stage"].bucket) == 63
    error_message = "The complete bucket name must accept the 63-character boundary."
  }
}

run "bucket_name_too_long" {
  command = plan

  variables {
    s3_bucket_name = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  }

  expect_failures = [aws_s3_bucket.backend]
}
