data "aws_rds_engine_version" "postgres" {
  engine  = "postgres"
  version = var.db_engine_version
}

# Exact filters ensure an unavailable class/version fails planning instead of
# silently substituting another instance class.
data "aws_rds_orderable_db_instance" "postgres" {
  engine                      = "postgres"
  engine_version              = data.aws_rds_engine_version.postgres.version
  instance_class              = var.db_instance_class
  storage_type                = var.db_storage_type
  vpc                         = true
  supports_storage_encryption = true
}

resource "aws_db_parameter_group" "postgres" {
  tags        = local.project_tags
  name_prefix = "${local.db_identifier}-"
  family      = data.aws_rds_engine_version.postgres.parameter_group_family
  description = "PostgreSQL with required TLS for ${var.project_name}."

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "postgres" {
  tags           = local.project_tags
  identifier     = local.db_identifier
  engine         = "postgres"
  engine_version = data.aws_rds_engine_version.postgres.version
  instance_class = var.db_instance_class

  # Omit db_name: RDS creates only its built-in postgres database.
  username                            = var.db_master_username
  manage_master_user_password         = true
  iam_database_authentication_enabled = false

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]
  parameter_group_name   = aws_db_parameter_group.postgres.name
  publicly_accessible    = false
  port                   = var.db_port
  multi_az               = var.db_multi_az

  storage_type          = var.db_storage_type
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_encrypted     = true
  kms_key_id            = var.db_kms_key_arn

  backup_retention_period = var.db_backup_retention_days
  backup_window           = var.db_backup_window
  maintenance_window      = var.db_maintenance_window
  copy_tags_to_snapshot   = true
  deletion_protection     = var.db_deletion_protection
  skip_final_snapshot     = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : coalesce(
    var.db_final_snapshot_identifier, "${local.db_identifier}-final"
  )

  apply_immediately           = var.db_apply_immediately
  auto_minor_version_upgrade  = var.db_auto_minor_version_upgrade
  allow_major_version_upgrade = var.db_allow_major_version_upgrade
  # Do not enroll an old major version in paid Extended Support automatically.
  engine_lifecycle_support = "open-source-rds-extended-support-disabled"

  depends_on = [aws_vpc_security_group_ingress_rule.eks_to_postgres]

  lifecycle {
    precondition {
      condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", local.db_identifier)) && !endswith(local.db_identifier, "-") && !strcontains(local.db_identifier, "--")
      error_message = "The derived RDS name is invalid; set db_identifier explicitly to a valid 1-63 character identifier."
    }
    precondition {
      condition     = var.db_allocated_storage >= data.aws_rds_orderable_db_instance.postgres.min_storage_size && var.db_allocated_storage <= data.aws_rds_orderable_db_instance.postgres.max_storage_size && (var.db_max_allocated_storage == 0 || var.db_max_allocated_storage <= data.aws_rds_orderable_db_instance.postgres.max_storage_size)
      error_message = "Initial storage and autoscaling limits must fit the selected RDS class/engine/storage limits."
    }
    precondition {
      condition     = !var.db_multi_az || data.aws_rds_orderable_db_instance.postgres.multi_az_capable
      error_message = "The selected RDS configuration does not support Multi-AZ."
    }
    precondition {
      condition     = var.db_max_allocated_storage == 0 || data.aws_rds_orderable_db_instance.postgres.supports_storage_autoscaling
      error_message = "The selected RDS configuration does not support storage autoscaling; set db_max_allocated_storage to 0."
    }
  }
}
