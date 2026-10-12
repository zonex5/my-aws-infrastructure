variable "aws_region" {
  description = "AWS region shared with infrastructure."
  type        = string
  nullable    = false
}

variable "project_name" {
  description = "Stable project identifier shared with infrastructure; discovers /qualitypro/<project_name>/network in AWS SSM."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,64}$", var.project_name))
    error_message = "Use a project identifier of 1-64 letters, digits, underscores or hyphens, matching infrastructure."
  }
}

variable "db_identifier" {
  description = "Optional RDS identifier; defaults to <normalized-project_name>-postgres. Supply explicitly if the derived name violates RDS naming limits."
  type        = string
  default     = null

  validation {
    condition     = var.db_identifier == null ? true : can(regex("^[a-z][a-z0-9-]{0,62}$", var.db_identifier)) && !endswith(var.db_identifier, "-") && !strcontains(var.db_identifier, "--")
    error_message = "Use 1-63 lowercase letters, digits or hyphens, starting with a letter, without trailing or consecutive hyphens."
  }
}

variable "db_instance_class" {
  description = "Exact RDS instance class, for example db.t4g.micro. Compatibility is checked in AWS at plan time."
  type        = string
  default     = "db.t4g.micro"
  nullable    = false

  validation {
    condition     = can(regex("^db\\.[a-z0-9]+\\.[a-z0-9]+$", var.db_instance_class))
    error_message = "Provide an RDS class such as db.t4g.micro."
  }
}

variable "db_engine_version" {
  description = "Exact available RDS PostgreSQL minor version, for example 17.10. AWS checks regional availability and class compatibility during plan."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+(-R[0-9]+)?$", var.db_engine_version))
    error_message = "Provide an exact PostgreSQL minor version such as 17.10 or an RDS revision such as 17.10-R2."
  }
}

variable "db_master_username" {
  description = "Initial PostgreSQL administrator; RDS generates and manages its password in Secrets Manager. Application users are created separately."
  type        = string
  default     = "postgres"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.db_master_username))
    error_message = "Use a PostgreSQL master username of 1-63 letters, digits or underscores, starting with a letter."
  }
}

variable "db_port" {
  description = "PostgreSQL listener port; security group and outputs use the same port."
  type        = number
  default     = 5432
  nullable    = false

  validation {
    condition     = var.db_port >= 1150 && var.db_port <= 65535 && floor(var.db_port) == var.db_port
    error_message = "Use an integer database port between 1150 and 65535."
  }
}

variable "db_allocated_storage" {
  description = "Initial database storage in GiB; the selected class/engine/storage combination determines AWS limits."
  type        = number
  default     = 20
  nullable    = false

  validation {
    condition     = var.db_allocated_storage >= 20 && floor(var.db_allocated_storage) == var.db_allocated_storage
    error_message = "Allocate at least 20 whole GiB."
  }
}

variable "db_max_allocated_storage" {
  description = "Storage autoscaling limit in GiB; 0 disables autoscaling."
  type        = number
  default     = 25
  nullable    = false

  validation {
    condition     = floor(var.db_max_allocated_storage) == var.db_max_allocated_storage && (var.db_max_allocated_storage == 0 || var.db_max_allocated_storage >= ceil(var.db_allocated_storage * 1.1))
    error_message = "Use 0 to disable autoscaling or a whole-GiB limit at least 10 percent above initial storage."
  }
}

variable "db_storage_type" {
  description = "General-purpose storage type. Provisioned-IOPS storage is outside this configuration."
  type        = string
  default     = "gp3"
  nullable    = false

  validation {
    condition     = contains(["gp2", "gp3"], var.db_storage_type)
    error_message = "Use gp2 or gp3."
  }
}

variable "db_kms_key_arn" {
  description = "Optional existing KMS key ARN for encrypted database storage; null uses the AWS-managed RDS key."
  type        = string
  default     = null
}

variable "db_multi_az" {
  description = "Enable an RDS standby in another Availability Zone if the selected class supports it."
  type        = bool
  default     = false
  nullable    = false
}

variable "db_backup_retention_days" {
  description = "Automated backup retention in days; 0 disables automated backups."
  type        = number
  default     = 0
  nullable    = false

  validation {
    condition     = var.db_backup_retention_days >= 0 && var.db_backup_retention_days <= 35 && floor(var.db_backup_retention_days) == var.db_backup_retention_days
    error_message = "Use an integer backup retention between 0 and 35 days."
  }
}

variable "db_backup_window" {
  description = "Optional daily UTC backup window in hh:mm-hh:mm format; null lets AWS select it. Must not overlap the maintenance window."
  type        = string
  default     = null
}

variable "db_maintenance_window" {
  description = "Optional weekly UTC maintenance window, for example sun:03:00-sun:04:00; null lets AWS select it."
  type        = string
  default     = null
}

variable "db_deletion_protection" {
  description = "Prevent RDS deletion. Apply false before intentionally destroying database."
  type        = bool
  default     = true
  nullable    = false
}

variable "db_skip_final_snapshot" {
  description = "Skip the final snapshot during intentional deletion; defaults to retaining a final snapshot."
  type        = bool
  default     = false
  nullable    = false
}

variable "db_final_snapshot_identifier" {
  description = "Optional unique final snapshot name; defaults to <db_identifier>-final. Change it if a snapshot with that name already exists."
  type        = string
  default     = null

  validation {
    condition     = var.db_final_snapshot_identifier == null ? true : can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,254}$", var.db_final_snapshot_identifier)) && !endswith(var.db_final_snapshot_identifier, "-") && !strcontains(var.db_final_snapshot_identifier, "--")
    error_message = "Use a snapshot identifier of 1-255 letters, digits or hyphens, starting with a letter and without trailing or consecutive hyphens."
  }
}

variable "db_apply_immediately" {
  description = "Apply changes immediately instead of waiting for maintenance; changes can restart the database."
  type        = bool
  default     = false
  nullable    = false
}

variable "db_auto_minor_version_upgrade" {
  description = "Allow AWS to apply minor version upgrades during maintenance."
  type        = bool
  default     = true
  nullable    = false
}

variable "db_allow_major_version_upgrade" {
  description = "Explicit opt-in for a future major engine upgrade; disabled for normal deployments."
  type        = bool
  default     = false
  nullable    = false
}
