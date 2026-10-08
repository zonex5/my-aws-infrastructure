# Exercise apply and teardown in a temporary test state using only mocked APIs.
# This verifies that the namespace -> Helm (including RBAC) -> Secret dependencies can be
# reversed during destroy without creating live infrastructure.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect    = "Allow"
          Action    = ["sts:AssumeRole"]
          Principal = { Service = "pods.eks.amazonaws.com" }
        }]
      })
    }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/test-role" }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::123456789012:policy/test-policy" }
  }
  mock_resource "aws_appsync_api" {
    defaults = { dns = { HTTP = "events.example.test", REALTIME = "events-realtime.example.test" } }
  }
}

mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "time" {}

variables {
  domain_name              = ["app.example.com", "argocd.example.com", "api.example.com"]
  argocd_domain_name       = "argocd.example.com"
  acm_certificate_arn      = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  cloudwatch_addon_version = "v5.0.0-eksbuild.1"
  application_namespaces = {
    "stage" = {
      s3_bucket_name          = "test-docs"
      cognito_user_pool_id    = "us-east-1_testing"
      backend_sns_topic_names = []
      appsync_event_api_name  = ["events"]
    }
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

run "apply_and_teardown" {
  command = apply

  assert {
    condition = (
      output.argocd_cluster_name == "in-cluster" &&
      yamldecode(helm_release.argocd.values[0]).createClusterRoles &&
      helm_release.argocd.namespace == "argocd"
    )
    error_message = "The self-hosted target must use Argo CD's cluster-wide RBAC."
  }
}

run "add_prod_to_existing_cluster" {
  command = apply

  variables {
    application_namespaces = {
      stage = {
        cognito_user_pool_id   = "us-east-1_testing"
        s3_bucket_name         = "test-docs"
        appsync_event_api_name = ["events"]
      }
      prod = {
        cognito_user_pool_id   = "us-east-1_Prod123"
        s3_bucket_name         = "reports"
        appsync_event_api_name = ["events"]
      }
    }
  }

  assert {
    condition = (
      output.cluster_arn == run.apply_and_teardown.cluster_arn &&
      output.argocd_cluster_name == run.apply_and_teardown.argocd_cluster_name &&
      output.application_pod_identities.stage == run.apply_and_teardown.application_pod_identities.stage &&
      output.s3_bucket_name.stage == run.apply_and_teardown.s3_bucket_name.stage &&
      output.appsync_event_api_id.stage == run.apply_and_teardown.appsync_event_api_id.stage &&
      yamldecode(helm_release.argocd.values[0]).createClusterRoles &&
      yamldecode(helm_release.argocd.values[0]).controller.clusterRoleRules.rules == [{
        apiGroups = ["*"]
        resources = ["*"]
        verbs     = ["*"]
      }]
    )
    error_message = "Adding prod must retain the existing cluster registration and stage resource identities."
  }
}
