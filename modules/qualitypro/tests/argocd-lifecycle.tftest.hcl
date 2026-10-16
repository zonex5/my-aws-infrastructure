# Exercise apply and teardown in a temporary test state using only mocked APIs.
# This verifies that the namespace -> Helm (including RBAC) -> Secret dependencies can be
# reversed during destroy without creating live infrastructure.
mock_provider "aws" {
  source = "./tests/mocks"
}

mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "time" {}

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
      toset(keys(output.application_pod_identities)) == toset(["stage", "prod"]) &&
      yamldecode(helm_release.argocd.values[0]).createClusterRoles &&
      helm_release.argocd.namespace == "argocd" &&
      jsondecode(aws_ssm_parameter.network.insecure_value).vpc_id == "vpc-00000000000000001" &&
      jsondecode(aws_ssm_parameter.network.insecure_value).node_security_group_id == "sg-00000000000000001"
    )
    error_message = "The self-hosted target must use Argo CD's cluster-wide RBAC."
  }
}

run "reapply_existing_shared_cluster" {
  command = apply

  assert {
    condition = (
      output.cluster_arn == run.apply_and_teardown.cluster_arn &&
      output.argocd_cluster_name == run.apply_and_teardown.argocd_cluster_name &&
      output.application_pod_identities.stage == run.apply_and_teardown.application_pod_identities.stage &&
      output.appsync_event_api_id.stage == run.apply_and_teardown.appsync_event_api_id.stage &&
      output.application_pod_identities.prod == run.apply_and_teardown.application_pod_identities.prod &&
      output.appsync_event_api_id.prod == run.apply_and_teardown.appsync_event_api_id.prod &&
      yamldecode(helm_release.argocd.values[0]).createClusterRoles &&
      yamldecode(helm_release.argocd.values[0]).controller.clusterRoleRules.rules == [{
        apiGroups = ["*"]
        resources = ["*"]
        verbs     = ["*"]
      }]
    )
    error_message = "Reapplying must retain the existing shared cluster and both namespaces resource identities."
  }
}
