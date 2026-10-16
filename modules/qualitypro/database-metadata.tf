resource "aws_ssm_parameter" "database" {
  tags        = local.project_tags
  name        = "/qualitypro/${var.project_name}/database"
  description = "Non-secret PostgreSQL connection metadata for ${var.project_name}."
  type        = "String"
  tier        = "Standard"

  insecure_value = jsonencode({
    schema_version          = 1
    project_name            = var.project_name
    aws_account_id          = data.aws_caller_identity.current.account_id
    aws_region              = var.aws_region
    database_host           = aws_db_instance.postgres.address
    database_port           = aws_db_instance.postgres.port
    database_endpoint       = local.database_endpoint
    database_url            = local.database_url
    administrative_database = local.administrative_database
    master_username         = aws_db_instance.postgres.username
    master_user_secret_arn  = aws_db_instance.postgres.master_user_secret[0].secret_arn
  })
}
