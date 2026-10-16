mock_provider "time" {}
mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "aws" {
  source = "./tests/mocks"
}

variables {
  node_availability_zone   = "us-east-1a"
  aws_region               = "us-east-1"
  project_name             = "cluster-1"
  cluster_name             = "cluster-1"
  kubernetes_version       = "1.36"
  node_instance_type       = "c7i-flex.large"
  node_min_size            = 2
  node_max_size            = 2
  node_desired_size        = 2
  domain_name              = ["app.example.com", "argocd.example.com", "api.example.com"]
  argocd_domain_name       = "argocd.example.com"
  acm_certificate_arn      = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  cloudwatch_addon_version = "v5.0.0-eksbuild.1"
  backend_sns_topic_names  = []
  appsync_event_api_name   = ["events"]
  s3_bucket_name           = "test-docs"
  db_engine_version        = "17.10"
  db_instance_class        = "db.t4g.micro"
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

override_module {
  target = module.eks
  outputs = {
    cluster_name                       = "cluster-1"
    cluster_arn                        = "arn:aws:eks:us-east-1:123456789012:cluster/cluster-1"
    cluster_endpoint                   = "https://eks.example.test"
    cluster_certificate_authority_data = "dGVzdA=="
    node_security_group_id             = "sg-00000000000000001"
  }
}

override_module {
  target = module.vpc
  outputs = {
    vpc_id                  = "vpc-00000000000000001"
    private_subnets         = ["subnet-00000000000000001", "subnet-00000000000000002"]
    public_subnets          = ["subnet-00000000000000003", "subnet-00000000000000004"]
    private_route_table_ids = ["rtb-00000000000000001", "rtb-00000000000000002"]
  }
}

override_data {
  target = data.aws_availability_zones.available
  values = { names = ["us-east-1a", "us-east-1b"] }
}
