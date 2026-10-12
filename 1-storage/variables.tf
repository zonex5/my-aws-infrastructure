variable "aws_region" {
  description = "AWS region for the S3 buckets; must match the infrastructure workspace."
  type        = string
  nullable    = false
}

variable "project_name" {
  description = "Stable project identifier/tag shared with infrastructure; publishes bucket metadata at /qualitypro/<project_name>/storage in AWS SSM."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,64}$", var.project_name))
    error_message = "Use a project identifier of 1-64 letters, digits, underscores or hyphens, matching infrastructure."
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
