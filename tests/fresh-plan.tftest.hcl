# Keep the real VPC/EKS modules: their IDs must remain unknown during a fresh plan.
mock_provider "aws" {
  source = "./modules/qualitypro/tests/mocks"

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:role/test-runner"
      user_id    = "test-runner"
    }
  }
  mock_data "aws_region" {
    defaults = { name = "us-east-1", region = "us-east-1" }
  }
  mock_data "aws_iam_session_context" {
    defaults = { issuer_arn = "arn:aws:iam::123456789012:role/test-runner" }
  }
}
mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "time" {}
mock_provider "tls" {}
mock_provider "cloudinit" {}
mock_provider "null" {}

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
  domain_name              = ["app.example.com", "argocd.example.com"]
  argocd_domain_name       = "argocd.example.com"
  acm_certificate_arn      = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  cloudwatch_addon_version = "v5.0.0-eksbuild.1"
  backend_sns_topic_names  = ["notifications"]
  appsync_event_api_name   = ["events"]
  s3_bucket_name           = "test-docs"
  db_engine_version        = "17.10"
  db_instance_class        = "db.t4g.micro"
}

override_data {
  target = module.qualitypro.data.aws_availability_zones.available
  values = { names = ["us-east-1a", "us-east-1b"] }
}

run "plan_from_empty_state" {
  command = plan

  assert {
    condition = (
      output.aws_account_id == "123456789012" &&
      toset(keys(output.application_pod_identities)) == toset(["stage", "prod"]) &&
      toset(keys(output.s3_bucket_name)) == toset(["stage", "prod"])
    )
    error_message = "The entire deployment must plan from empty state without pre-existing SSM metadata or known VPC, subnet and cluster IDs."
  }
}
