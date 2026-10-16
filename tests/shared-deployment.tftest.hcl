mock_provider "aws" {
  source = "./modules/qualitypro/tests/mocks"
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
  target = module.qualitypro.module.eks
  outputs = {
    cluster_name                       = "cluster-1"
    cluster_arn                        = "arn:aws:eks:us-east-1:123456789012:cluster/cluster-1"
    cluster_endpoint                   = "https://eks.example.test"
    cluster_certificate_authority_data = "dGVzdA=="
    node_security_group_id             = "sg-00000000000000001"
  }
}

override_module {
  target = module.qualitypro.module.vpc
  outputs = {
    vpc_id                  = "vpc-00000000000000001"
    private_subnets         = ["subnet-00000000000000001", "subnet-00000000000000002"]
    public_subnets          = ["subnet-00000000000000003", "subnet-00000000000000004"]
    private_route_table_ids = ["rtb-00000000000000001", "rtb-00000000000000002"]
  }
}
override_data {
  target = module.qualitypro.data.aws_availability_zones.available
  values = { names = ["us-east-1a", "us-east-1b"] }
}
run "fresh_shared_deployment" {
  command = apply

  assert {
    condition = (
      output.cluster_name == "cluster-1" &&
      toset(keys(output.application_pod_identities)) == toset(["stage", "prod"]) &&
      toset(keys(output.s3_bucket_name)) == toset(["stage", "prod"]) &&
      output.vpc_id == "vpc-00000000000000001" &&
      output.database_url == "postgresql://postgres.example.us-east-1.rds.amazonaws.com:5432/postgres?sslmode=require" &&
      output.master_user_secret_arn == "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!db-test-admin" &&
      output.argocd_server_url == "https://argocd.example.com"
    )
    error_message = "One root must create both application namespaces/buckets, one shared cluster and one shared private database, forwarding the module outputs."
  }
}

run "reapply_shared_deployment" {
  command = apply

  assert {
    condition = (
      output.cluster_arn == run.fresh_shared_deployment.cluster_arn &&
      output.database_arn == run.fresh_shared_deployment.database_arn &&
      output.s3_bucket_name == run.fresh_shared_deployment.s3_bucket_name &&
      output.application_pod_identities == run.fresh_shared_deployment.application_pod_identities
    )
    error_message = "Reapplying must preserve both namespaces and the shared cluster, buckets and database identities."
  }
}
