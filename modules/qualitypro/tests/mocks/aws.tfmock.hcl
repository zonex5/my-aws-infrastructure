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
mock_resource "aws_iam_role" {
  defaults = { arn = "arn:aws:iam::123456789012:role/test-role" }
}
mock_resource "aws_iam_policy" {
  defaults = { arn = "arn:aws:iam::123456789012:policy/test-policy" }
}
mock_resource "aws_appsync_api" {
  defaults = { dns = { HTTP = "events.example.test", REALTIME = "events-realtime.example.test" } }
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
