variable "aws_region" {
  description = "AWS region for all infrastructure."
  type        = string
  nullable    = false
}

variable "project_name" {
  description = "Stable project identifier used for storage/database names, tags and published metadata."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,64}$", var.project_name))
    error_message = "Use a project identifier of 1-64 letters, digits, underscores or hyphens, for this deployment."
  }
}

variable "cluster_name" {
  description = "Unique EKS cluster name and resource name prefix."
  type        = string
  nullable    = false
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version supported by Istio."
  type        = string
  nullable    = false
}

variable "domain_name" {
  description = "Hostnames or wildcard hostnames (for example *.example.com) forwarded by the shared ALB to the Istio ingress gateway."
  type        = list(string)
  nullable    = false

  validation {
    condition = length(var.domain_name) > 0 && alltrue([
      for hostname in var.domain_name : can(regex("^([*][.])?[A-Za-z0-9][A-Za-z0-9.-]*[.][A-Za-z0-9-]+$", hostname))
    ])
    error_message = "Provide at least one hostname without a scheme, path or port; wildcards are allowed only as a leading *. prefix (for example *.example.com)."
  }
}

variable "vpc_cidr" {
  description = "CIDR range for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Exactly two public subnet CIDRs, one per selected AZ."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Provide exactly two public subnet CIDRs."
  }
}

variable "private_subnet_cidrs" {
  description = "Exactly two private subnet CIDRs, one per selected AZ."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Provide exactly two private subnet CIDRs."
  }
}

variable "nat_gateway_per_az" {
  description = "Create a NAT gateway in each AZ; set false only for cheaper non-production environments."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to access the public EKS API endpoint; narrow for production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cloudwatch_log_retention_days" {
  description = "Retention in days for the EKS control plane CloudWatch log group. Container log groups created by the add-on have separate retention settings."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.cloudwatch_log_retention_days)
    error_message = "Choose a CloudWatch Logs supported retention period in days."
  }
}

variable "cloudwatch_addon_version" {
  description = "Optional EKS build version of amazon-cloudwatch-observability; null selects the latest compatible version at plan time. Use version 5.0.0 or newer for opt-in Application Signals."
  type        = string
  default     = null

  validation {
    condition     = var.cloudwatch_addon_version == null || can(regex("^v([5-9]|[1-9][0-9]+)\\.[0-9]+\\.[0-9]+-eksbuild\\.[0-9]+$", var.cloudwatch_addon_version))
    error_message = "Use an EKS add-on version v5.0.0-eksbuild.1 or newer."
  }
}

variable "node_availability_zone" {
  description = "Availability Zone for all worker nodes; must be available in aws_region."
  type        = string
  nullable    = false
}

variable "node_instance_type" {
  description = "Required single EC2 instance type for the managed node group."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.node_instance_type)) > 0 && var.node_instance_type == trimspace(var.node_instance_type)
    error_message = "Provide one EC2 instance type without leading or trailing spaces, such as c7i-flex.large."
  }
}

variable "node_capacity_type" {
  description = "Managed node group capacity type."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "Choose ON_DEMAND or SPOT."
  }
}

variable "node_min_size" {
  description = "Managed node group minimum size."
  type        = number
  nullable    = false
}

variable "node_max_size" {
  description = "Managed node group maximum size."
  type        = number
  nullable    = false
}

variable "node_desired_size" {
  description = "Managed node group desired size."
  type        = number
  nullable    = false
}

variable "acm_certificate_arn" {
  description = "ARN of an existing ACM certificate in aws_region covering all ALB hostnames."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[a-z0-9-]+:acm:${var.aws_region}:[0-9]{12}:certificate/[0-9a-f-]+$", var.acm_certificate_arn))
    error_message = "Provide an existing ACM certificate ARN in the same region as the ALB (aws_region)."
  }
}

variable "backend_sns_topic_names" {
  description = "Required shared SNS topic base names for both stage and prod. Explicitly supply an empty list to disable SNS/SQS in both environments. In HCP Terraform, enable HCL and enter a list such as [\"notifications\", \"audit\"]."
  type        = list(string)
  nullable    = false

  validation {
    condition = length(var.backend_sns_topic_names) == length(distinct(var.backend_sns_topic_names)) && alltrue([
      for name in var.backend_sns_topic_names : can(regex("^[A-Za-z0-9_-]{1,70}$", name))
    ])
    error_message = "Provide unique SNS base names of 1-70 letters, digits, hyphens, or underscores; stage-<name>-sub must fit within SQS's 80-character limit."
  }
}

variable "appsync_event_api_name" {
  description = "Shared AppSync Event API base names for both stage and prod. In HCP Terraform, enable HCL and enter a non-empty list such as [\"events\", \"other\"]."
  type        = list(string)
  nullable    = false

  validation {
    condition = length(var.appsync_event_api_name) > 0 && length(var.appsync_event_api_name) == length(distinct(var.appsync_event_api_name)) && alltrue([
      for name in var.appsync_event_api_name : can(regex("^[A-Za-z0-9_ -]{1,44}$", name)) && name == trimspace(name)
    ])
    error_message = "Provide a non-empty list of unique AppSync base names of 1-44 letters, digits, underscores, hyphens, or spaces, without leading or trailing spaces; stage-<name> must fit within 50 characters."
  }
}

variable "appsync_event_namespace_name" {
  description = "Shared channel namespace inside every stage/prod AppSync API. In HCP Terraform, enter with HCL disabled."
  type        = string
  default     = "events"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,48}[A-Za-z0-9])?$", var.appsync_event_namespace_name))
    error_message = "Use an AppSync channel namespace of 1-50 letters, digits, or hyphens, starting and ending with a letter or digit."
  }
}

variable "external_secrets_secret_arns" {
  description = "Secrets Manager secret ARNs or ARN patterns readable by External Secrets Operator. Empty defaults to <namespace>/* for every application namespace in this AWS account and region."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for arn in var.external_secrets_secret_arns : can(regex("^arn:[a-z0-9-]+:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:.+$", arn))
    ])
    error_message = "Provide Secrets Manager secret ARNs or ARN patterns with an explicit region and account ID."
  }
}

variable "external_secrets_kms_key_arns" {
  description = "Optional customer-managed KMS key ARNs used by Secrets Manager secrets. Key policies must also allow the operator role."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for arn in var.external_secrets_kms_key_arns : can(regex("^arn:[a-z0-9-]+:kms:[a-z0-9-]+:[0-9]{12}:key/[A-Za-z0-9-]+$", arn))
    ])
    error_message = "Provide customer-managed KMS key ARNs, not aliases or wildcard resources."
  }
}

variable "argocd_domain_name" {
  description = "Public Argo CD hostname; cover it with an exact or wildcard entry in domain_name and the ACM certificate."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9.-]*[.][A-Za-z0-9-]+$", var.argocd_domain_name))
    error_message = "Provide a hostname without a scheme, path or port."
  }
}

variable "s3_bucket_name" {
  description = "Shared S3 base name; creates <namespace>-<name>-<account-id>-<region>. The current account/region suffix is added only when absent. The complete name must fit within 63 characters. In HCP Terraform, enter with HCL disabled."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,55}[a-z0-9])?$", var.s3_bucket_name))
    error_message = "Use an S3 base name of 1-57 lowercase letters, digits, or hyphens, starting and ending with a letter or digit. The stage- prefix and account/region suffix must fit within S3's 63-character limit."
  }
}

variable "s3_force_destroy" {
  description = "Allow Terraform destroy to delete all objects and versions in both application S3 buckets. Apply true before destroying a disposable deployment; keep false for normal deployments."
  type        = bool
  default     = false
  nullable    = false
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
  description = "Required exact RDS instance class, for example db.t4g.micro. Compatibility is checked in AWS at plan time."
  type        = string
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
  default     = 100
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
  default     = 7
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
