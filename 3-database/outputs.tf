output "database_host" {
  description = "Private RDS hostname, reachable from the cluster VPC."
  value       = aws_db_instance.postgres.address
}

output "database_port" {
  description = "PostgreSQL port, also used by the EKS client ingress rule."
  value       = aws_db_instance.postgres.port
}

output "database_endpoint" {
  description = "Private RDS hostname and port."
  value       = local.database_endpoint
}

output "database_url" {
  description = "Credential-free TLS connection URL to the built-in postgres database; replace the database path after creating your application database."
  value       = local.database_url
}

output "database_arn" {
  description = "RDS instance ARN."
  value       = aws_db_instance.postgres.arn
}

output "database_security_group_id" {
  description = "Private database security group allowing PostgreSQL traffic from EKS nodes."
  value       = aws_security_group.postgres.id
}

output "master_username" {
  description = "Initial PostgreSQL administrator username; password is retrieved separately from Secrets Manager."
  value       = aws_db_instance.postgres.username
}

output "master_user_secret_arn" {
  description = "RDS-managed Secrets Manager secret ARN; the password itself is not read into Terraform state or outputs."
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
}

output "database_metadata_parameter_name" {
  description = "SSM parameter automatically publishing the endpoint and secret ARN for operator tooling."
  value       = aws_ssm_parameter.database.name
}
