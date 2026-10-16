locals {
  db_identifier = coalesce(var.db_identifier, "${lower(replace(var.project_name, "_", "-"))}-postgres")

  # RDS creates postgres itself. No application database or SQL users are managed.
  administrative_database = "postgres"
  database_endpoint       = "${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}"
  database_url            = "postgresql://${local.database_endpoint}/${local.administrative_database}?sslmode=require"
}
