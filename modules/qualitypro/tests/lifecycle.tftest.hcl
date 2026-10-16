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
