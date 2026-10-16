mock_provider "time" {}
mock_provider "helm" {}
mock_provider "kubernetes" {}
# Only mocked AWS APIs are used, including apply/teardown. No live RDS is created.
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

run "private_postgres_with_managed_password" {
  command = apply

  assert {
    condition = (
      aws_db_instance.postgres.engine == "postgres" &&
      aws_db_instance.postgres.engine_version == "17.10" &&
      aws_db_instance.postgres.instance_class == "db.t4g.micro" &&
      !aws_db_instance.postgres.publicly_accessible &&
      aws_db_instance.postgres.storage_encrypted &&
      aws_db_instance.postgres.manage_master_user_password &&
      !aws_db_instance.postgres.iam_database_authentication_enabled &&
      aws_db_instance.postgres.username == "postgres" &&
      aws_db_instance.postgres.password == null &&
      contains(["", "postgres"], aws_db_instance.postgres.db_name) &&
      aws_db_instance.postgres.deletion_protection &&
      !aws_db_instance.postgres.skip_final_snapshot &&
      aws_db_instance.postgres.backup_retention_period == 7
    )
    error_message = "RDS must be private/encrypted, use password login with an RDS-managed postgres administrator, create no application database, and retain backups."
  }

  assert {
    condition = (
      toset(aws_db_subnet_group.postgres.subnet_ids) == toset(["subnet-00000000000000001", "subnet-00000000000000002"]) &&
      aws_security_group.postgres.vpc_id == "vpc-00000000000000001" &&
      toset(aws_db_instance.postgres.vpc_security_group_ids) == toset([aws_security_group.postgres.id]) &&
      aws_vpc_security_group_ingress_rule.eks_to_postgres.security_group_id == aws_security_group.postgres.id &&
      aws_vpc_security_group_ingress_rule.eks_to_postgres.referenced_security_group_id == "sg-00000000000000001" &&
      aws_vpc_security_group_ingress_rule.eks_to_postgres.cidr_ipv4 == null &&
      aws_vpc_security_group_ingress_rule.eks_to_postgres.cidr_ipv6 == null &&
      aws_vpc_security_group_ingress_rule.eks_to_postgres.from_port == 5432 &&
      aws_vpc_security_group_ingress_rule.eks_to_postgres.to_port == 5432 &&
      aws_vpc_security_group_ingress_rule.eks_to_postgres.ip_protocol == "tcp" &&
      aws_db_parameter_group.postgres.family == "postgres17" &&
      one(aws_db_parameter_group.postgres.parameter).name == "rds.force_ssl" &&
      one(aws_db_parameter_group.postgres.parameter).value == "1"
    )
    error_message = "Only the EKS client SG may connect on the PostgreSQL port, in the existing private network, with TLS required."
  }

  assert {
    condition = (
      output.database_url == "postgresql://postgres.example.us-east-1.rds.amazonaws.com:5432/postgres?sslmode=require" &&
      !strcontains(output.database_url, "@") &&
      output.master_user_secret_arn == "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!db-test-admin" &&
      output.database_metadata_parameter_name == "/qualitypro/cluster-1/database" &&
      jsondecode(aws_ssm_parameter.database.insecure_value).database_url == output.database_url &&
      jsondecode(aws_ssm_parameter.database.insecure_value).master_user_secret_arn == output.master_user_secret_arn &&
      !contains(keys(jsondecode(aws_ssm_parameter.database.insecure_value)), "password")
    )
    error_message = "Connection metadata must expose a credential-free postgres URL and the secret ARN, without reading or publishing the password."
  }
}

run "configurable_instance_port_and_storage" {
  command = plan

  variables {
    db_instance_class        = "db.t4g.small"
    db_port                  = 5433
    db_allocated_storage     = 40
    db_max_allocated_storage = 200
    db_multi_az              = true
    db_backup_retention_days = 14
  }

  assert {
    condition = (
      data.aws_rds_orderable_db_instance.postgres.instance_class == "db.t4g.small" &&
      aws_db_instance.postgres.instance_class == "db.t4g.small" &&
      aws_db_instance.postgres.port == 5433 &&
      aws_vpc_security_group_ingress_rule.eks_to_postgres.from_port == 5433 &&
      aws_vpc_security_group_ingress_rule.eks_to_postgres.to_port == 5433 &&
      output.database_url == "postgresql://postgres.example.us-east-1.rds.amazonaws.com:5433/postgres?sslmode=require" &&
      aws_db_instance.postgres.allocated_storage == 40 &&
      aws_db_instance.postgres.max_allocated_storage == 200 &&
      aws_db_instance.postgres.multi_az &&
      aws_db_instance.postgres.backup_retention_period == 14
    )
    error_message = "Variable changes must drive the exact RDS class, port, security rule, URL, storage and backup settings together."
  }
}

run "reject_unsupported_multi_az" {
  command = plan

  variables {
    db_multi_az = true
  }

  override_data {
    target = data.aws_rds_orderable_db_instance.postgres
    values = {
      min_storage_size             = 20
      max_storage_size             = 65536
      multi_az_capable             = false
      supports_storage_autoscaling = true
    }
  }

  expect_failures = [aws_db_instance.postgres]
}

run "reject_storage_outside_service_limits" {
  command = plan

  override_data {
    target = data.aws_rds_orderable_db_instance.postgres
    values = {
      min_storage_size             = 100
      max_storage_size             = 65536
      multi_az_capable             = true
      supports_storage_autoscaling = true
    }
  }

  expect_failures = [aws_db_instance.postgres]
}

run "reject_small_autoscaling_limit" {
  command = plan

  variables {
    db_allocated_storage     = 100
    db_max_allocated_storage = 105
  }

  expect_failures = [var.db_max_allocated_storage]
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
