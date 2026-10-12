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

run "apply_storage" {
  command = apply

  assert {
    condition = (
      toset(keys(output.s3_bucket_name)) == toset(["stage", "prod"]) &&
      alltrue([for bucket in aws_s3_bucket.backend : !bucket.force_destroy]) &&
      jsondecode(aws_ssm_parameter.storage.insecure_value).s3_bucket_name == output.s3_bucket_name &&
      jsondecode(aws_ssm_parameter.storage.insecure_value).s3_bucket_arn == output.s3_bucket_arn
    )
    error_message = "Normal storage deployments must not opt in to deleting bucket contents."
  }
}

run "prepare_disposable_storage_teardown" {
  command = apply

  variables {
    s3_force_destroy = true
  }

  assert {
    condition = (
      alltrue([for bucket in aws_s3_bucket.backend : bucket.force_destroy]) &&
      output.s3_bucket_name == run.apply_storage.s3_bucket_name &&
      output.s3_bucket_arn == run.apply_storage.s3_bucket_arn &&
      output.storage_metadata_parameter_name == run.apply_storage.storage_metadata_parameter_name &&
      jsondecode(aws_ssm_parameter.storage.insecure_value).s3_bucket_arn == output.s3_bucket_arn
    )
    error_message = "Teardown opt-in must update both existing buckets without replacing them."
  }
}
