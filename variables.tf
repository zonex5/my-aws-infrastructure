variable "aws_region" {
  description = "AWS region for all infrastructure."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Unique EKS cluster name and resource name prefix."
  type        = string
  default     = "cluster-1"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version supported by Istio."
  type        = string
  default     = "1.36"
}

variable "domain_name" {
  description = "Hostnames forwarded by the shared ALB to the Istio ingress gateway."
  type        = list(string)

  validation {
    condition = length(var.domain_name) > 0 && alltrue([
      for hostname in var.domain_name : can(regex("^[A-Za-z0-9][A-Za-z0-9.-]*[.][A-Za-z0-9-]+$", hostname))
    ])
    error_message = "Provide at least one hostname without a scheme, path or port."
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

variable "node_instance_types" {
  description = "Managed node group EC2 instance types."
  type        = list(string)
  default     = ["c7i-flex.large"]
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
  default     = 1
}

variable "node_max_size" {
  description = "Managed node group maximum size."
  type        = number
  default     = 1
}

variable "node_desired_size" {
  description = "Managed node group desired size."
  type        = number
  default     = 1
}

variable "acm_certificate_arn" {
  description = "ARN of an existing us-east-1 ACM certificate covering the domain."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:acm:us-east-1:[0-9]{12}:certificate/[0-9a-f-]+$", var.acm_certificate_arn))
    error_message = "Provide an existing us-east-1 ACM certificate ARN."
  }
}

variable "s3_bucket_name" {
  description = "Base name for the backend S3 bucket created as <application_namespace>-<s3_bucket_name>-<account-id>-<region>. The full name must not exceed 63 characters."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$", var.s3_bucket_name))
    error_message = "Use a 3-40 character lowercase S3 prefix containing only letters, digits, or hyphens; start and end with a letter or digit."
  }
}

variable "backend_sns_topic_names" {
  description = "SNS topic base names created as <application_namespace>-<name>, with an SQS queue <application_namespace>-<name>-sub. Standard topics and queues only."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition = length(var.backend_sns_topic_names) == length(distinct(var.backend_sns_topic_names)) && alltrue([
      for name in var.backend_sns_topic_names :
      can(regex("^[A-Za-z0-9_-]{1,74}$", name))
    ])
    error_message = "Provide unique SNS topic base names of 1-74 letters, digits, hyphens, or underscores. The namespace-prefixed SQS queue name must also fit within 80 characters."
  }
}

variable "application_namespace" {
  description = "Single Kubernetes application namespace with Istio injection, backend/frontend IAM roles and Pod Identity associations. Also prefixes the S3 bucket, SNS/SQS and AppSync resource names."
  type        = string
  default     = "stage"
  nullable    = false

  validation {
    condition = (
      can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.application_namespace)) &&
      !startswith(var.application_namespace, "kube-") &&
      !contains(["default", "istio-system", "argocd", "amazon-cloudwatch", "external-secrets"], var.application_namespace)
    )
    error_message = "Provide one Kubernetes namespace name: 1-63 lowercase letters, digits, or hyphens, starting and ending with a letter or digit. System namespaces are not allowed."
  }
}

variable "appsync_event_api_name" {
  description = "AppSync Event API base names created as <application_namespace>-<name>, accessible only to the application namespace's frontend pod role."
  type        = list(string)
  nullable    = false

  validation {
    condition = length(var.appsync_event_api_name) > 0 && length(var.appsync_event_api_name) == length(distinct(var.appsync_event_api_name)) && alltrue([
      for name in var.appsync_event_api_name : can(regex("^[A-Za-z0-9_ -]{1,48}$", name)) && name == trimspace(name) && length(name) > 0
    ])
    error_message = "Provide a non-empty list of unique AppSync API base names: 1-48 letters, digits, underscores, hyphens, or spaces, without leading or trailing spaces. The namespace-prefixed API name must also fit within 50 characters."
  }
}

variable "appsync_event_namespace_name" {
  description = "Channel namespace accessible to frontend pods in the AppSync Event API."
  type        = string
  default     = "events"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,48}[A-Za-z0-9])?$", var.appsync_event_namespace_name))
    error_message = "Use 1-50 letters, digits, or hyphens; start and end with a letter or digit."
  }
}

variable "cognito_user_pool_id" {
  description = "ID of an existing Cognito User Pool in us-east-1."
  type        = string
}

variable "external_secrets_secret_arns" {
  description = "Secrets Manager secret ARNs or ARN patterns readable by External Secrets Operator. Empty defaults to <application_namespace>/* in this AWS account and region."
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
  description = "Public Argo CD hostname; include it in domain_name and the ACM certificate."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9.-]*[.][A-Za-z0-9-]+$", var.argocd_domain_name))
    error_message = "Provide a hostname without a scheme, path or port."
  }
}
