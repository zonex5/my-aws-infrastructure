locals {
  network       = jsondecode(data.aws_ssm_parameter.network.insecure_value)
  db_identifier = coalesce(var.db_identifier, "${lower(replace(var.project_name, "_", "-"))}-postgres")

  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }

  # RDS creates postgres itself. No application database or SQL users are managed.
  administrative_database = "postgres"
  database_endpoint       = "${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}"
  database_url            = "postgresql://${local.database_endpoint}/${local.administrative_database}?sslmode=require"
}
