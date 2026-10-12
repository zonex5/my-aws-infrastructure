# Only mocked AWS APIs are used, including apply/teardown. No live RDS is created.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_ssm_parameter" {
    defaults = {
      type = "String"
      insecure_value = jsonencode({
        schema_version         = 1
        project_name           = "cluster-1"
        aws_account_id         = "123456789012"
        aws_region             = "us-east-1"
        vpc_id                 = "vpc-00000000000000001"
        private_subnet_ids     = ["subnet-00000000000000001", "subnet-00000000000000002"]
        node_security_group_id = "sg-00000000000000001"
      })
    }
  }
  mock_data "aws_rds_engine_version" {
    defaults = { parameter_group_family = "postgres17" }
  }
  mock_data "aws_rds_orderable_db_instance" {
    defaults = {
      min_storage_size             = 20
      max_storage_size             = 65536
      multi_az_capable             = true
      supports_storage_autoscaling = true
    }
  }
  mock_data "aws_security_group" {
    defaults = { vpc_id = "vpc-00000000000000001" }
  }
  mock_resource "aws_db_instance" {
    defaults = {
      address = "postgres.example.us-east-1.rds.amazonaws.com"
      arn     = "arn:aws:rds:us-east-1:123456789012:db:cluster-1-postgres"
      db_name = ""
      master_user_secret = [{
        secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!db-test-admin"
        secret_status = "active"
        kms_key_id    = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
      }]
    }
  }
}

variables {
  aws_region        = "us-east-1"
  project_name      = "cluster-1"
  db_engine_version = "17.10"
}

override_data {
  target = data.aws_subnet.database["subnet-00000000000000001"]
  values = {
    vpc_id                  = "vpc-00000000000000001"
    availability_zone       = "us-east-1a"
    map_public_ip_on_launch = false
  }
}

override_data {
  target = data.aws_subnet.database["subnet-00000000000000002"]
  values = {
    vpc_id                  = "vpc-00000000000000001"
    availability_zone       = "us-east-1b"
    map_public_ip_on_launch = false
  }
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

run "reject_network_from_another_account" {
  command = plan

  override_data {
    target = data.aws_ssm_parameter.network
    values = {
      type = "String"
      insecure_value = jsonencode({
        schema_version         = 1
        project_name           = "cluster-1"
        aws_account_id         = "999999999999"
        aws_region             = "us-east-1"
        vpc_id                 = "vpc-00000000000000001"
        private_subnet_ids     = ["subnet-00000000000000001", "subnet-00000000000000002"]
        node_security_group_id = "sg-00000000000000001"
      })
    }
  }

  expect_failures = [data.aws_ssm_parameter.network]
}

run "reject_network_from_another_region" {
  command = plan

  override_data {
    target = data.aws_ssm_parameter.network
    values = {
      type = "String"
      insecure_value = jsonencode({
        schema_version         = 1
        project_name           = "cluster-1"
        aws_account_id         = "123456789012"
        aws_region             = "eu-west-1"
        vpc_id                 = "vpc-00000000000000001"
        private_subnet_ids     = ["subnet-00000000000000001", "subnet-00000000000000002"]
        node_security_group_id = "sg-00000000000000001"
      })
    }
  }

  expect_failures = [data.aws_ssm_parameter.network]
}

run "reject_same_az_subnets" {
  command = plan

  override_data {
    target = data.aws_subnet.database["subnet-00000000000000002"]
    values = {
      vpc_id                  = "vpc-00000000000000001"
      availability_zone       = "us-east-1a"
      map_public_ip_on_launch = false
    }
  }

  expect_failures = [aws_db_subnet_group.postgres]
}

run "reject_subnet_in_another_vpc" {
  command = plan

  override_data {
    target = data.aws_subnet.database["subnet-00000000000000002"]
    values = {
      vpc_id                  = "vpc-00000000000000002"
      availability_zone       = "us-east-1b"
      map_public_ip_on_launch = false
    }
  }

  expect_failures = [data.aws_subnet.database["subnet-00000000000000002"]]
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
