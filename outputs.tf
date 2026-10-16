output "s3_bucket_name" {
  description = "Backend S3 bucket names keyed by application environment."
  value       = module.qualitypro.s3_bucket_name
}

output "s3_bucket_arn" {
  description = "Backend S3 bucket ARNs keyed by application environment, consumed by infrastructure IAM policies."
  value       = module.qualitypro.s3_bucket_arn
}

output "aws_account_id" {
  description = "AWS account owning this deployment."
  value       = module.qualitypro.aws_account_id
}

output "aws_region" {
  description = "AWS region of this deployment."
  value       = module.qualitypro.aws_region
}

output "storage_metadata_parameter_name" {
  description = "SSM parameter publishing non-secret bucket metadata for external tooling."
  value       = module.qualitypro.storage_metadata_parameter_name
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.qualitypro.cluster_name
}

output "external_secrets_namespace" {
  description = "Namespace containing External Secrets Operator."
  value       = module.qualitypro.external_secrets_namespace
}

output "external_secrets_pod_role_arn" {
  description = "Pod Identity IAM role used by External Secrets Operator to read Secrets Manager."
  value       = module.qualitypro.external_secrets_pod_role_arn
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.qualitypro.cluster_arn
}

output "cluster_endpoint" {
  description = "EKS Kubernetes API endpoint."
  value       = module.qualitypro.cluster_endpoint
}

output "vpc_id" {
  description = "VPC identifier."
  value       = module.qualitypro.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet identifiers used by worker nodes."
  value       = module.qualitypro.private_subnet_ids
}

output "node_security_group_id" {
  description = "EKS node security group used by private services to allow pod connections."
  value       = module.qualitypro.node_security_group_id
}

output "network_metadata_parameter_name" {
  description = "SSM parameter publishing non-secret network metadata for external tooling."
  value       = module.qualitypro.network_metadata_parameter_name
}

output "public_subnet_ids" {
  description = "Public subnet identifiers used by the ALB."
  value       = module.qualitypro.public_subnet_ids
}

output "alb_dns_name" {
  description = "Controller-created ALB DNS name for the manual app CNAME."
  value       = module.qualitypro.alb_dns_name
}

output "backend_service_account_name" {
  description = "Application backend ServiceAccount name."
  value       = module.qualitypro.backend_service_account_name
}

output "backend_pod_role_arn" {
  description = "Backend Pod Identity IAM role ARNs keyed by Kubernetes namespace."
  value       = module.qualitypro.backend_pod_role_arn
}

output "frontend_service_account_name" {
  description = "Frontend ServiceAccount name in the application namespace."
  value       = module.qualitypro.frontend_service_account_name
}

output "frontend_pod_role_arn" {
  description = "Frontend Pod Identity IAM role ARNs keyed by Kubernetes namespace."
  value       = module.qualitypro.frontend_pod_role_arn
}

output "application_pod_identities" {
  description = "Backend and frontend ServiceAccounts, namespace-specific IAM roles, and Pod Identity association IDs keyed by Kubernetes namespace."
  value       = module.qualitypro.application_pod_identities
}

output "appsync_event_api_id" {
  description = "AppSync Event API IDs keyed by Kubernetes namespace and API base name."
  value       = module.qualitypro.appsync_event_api_id
}

output "appsync_event_api_arn" {
  description = "AppSync Event API ARNs keyed by Kubernetes namespace and API base name."
  value       = module.qualitypro.appsync_event_api_arn
}

output "appsync_event_http_endpoint" {
  description = "AppSync HTTP publish endpoints keyed by Kubernetes namespace and API base name."
  value       = module.qualitypro.appsync_event_http_endpoint
}

output "appsync_event_realtime_endpoint" {
  description = "AppSync IAM WebSocket endpoints keyed by Kubernetes namespace and API base name."
  value       = module.qualitypro.appsync_event_realtime_endpoint
}

output "appsync_event_namespace_name" {
  description = "AppSync channel namespace names keyed by Kubernetes application namespace."
  value       = module.qualitypro.appsync_event_namespace_name
}

output "cloudwatch_observability_addon_version" {
  description = "Installed Amazon CloudWatch Observability EKS add-on version."
  value       = module.qualitypro.cloudwatch_observability_addon_version
}

output "cloudwatch_control_plane_log_group" {
  description = "CloudWatch Logs group for EKS control plane logs."
  value       = module.qualitypro.cloudwatch_control_plane_log_group
}

output "backend_sns_topic_arns" {
  description = "Created SNS topic ARNs keyed by Kubernetes namespace and topic base name."
  value       = module.qualitypro.backend_sns_topic_arns
}

output "backend_sqs_queue_arns" {
  description = "Created SQS queue ARNs keyed by Kubernetes namespace and SNS topic base name."
  value       = module.qualitypro.backend_sqs_queue_arns
}

output "backend_sqs_queue_urls" {
  description = "Created SQS queue URLs keyed by Kubernetes namespace and SNS topic base name."
  value       = module.qualitypro.backend_sqs_queue_urls
}

output "argocd_server_url" {
  description = "Self-hosted Argo CD UI and API URL with TLS terminated at the ALB."
  value       = module.qualitypro.argocd_server_url
}

output "argocd_cluster_name" {
  description = "Registered Argo CD target name for Application destination.name."
  value       = module.qualitypro.argocd_cluster_name
}

output "argocd_cluster_server" {
  description = "Local Kubernetes API address for Application destination.server."
  value       = module.qualitypro.argocd_cluster_server
}

output "database_host" {
  description = "Private RDS hostname, reachable from the cluster VPC."
  value       = module.qualitypro.database_host
}

output "database_port" {
  description = "PostgreSQL port, also used by the EKS client ingress rule."
  value       = module.qualitypro.database_port
}

output "database_endpoint" {
  description = "Private RDS hostname and port."
  value       = module.qualitypro.database_endpoint
}

output "database_url" {
  description = "Credential-free TLS connection URL to the built-in postgres database; replace the database path after creating your application database."
  value       = module.qualitypro.database_url
}

output "database_arn" {
  description = "RDS instance ARN."
  value       = module.qualitypro.database_arn
}

output "database_security_group_id" {
  description = "Private database security group allowing PostgreSQL traffic from EKS nodes."
  value       = module.qualitypro.database_security_group_id
}

output "master_username" {
  description = "Initial PostgreSQL administrator username; password is retrieved separately from Secrets Manager."
  value       = module.qualitypro.master_username
}

output "master_user_secret_arn" {
  description = "RDS-managed Secrets Manager secret ARN; the password itself is not read into Terraform state or outputs."
  value       = module.qualitypro.master_user_secret_arn
}

output "database_metadata_parameter_name" {
  description = "SSM parameter automatically publishing the endpoint and secret ARN for operator tooling."
  value       = module.qualitypro.database_metadata_parameter_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 EKS CA certificate for the caller's Kubernetes and Helm providers."
  value       = module.qualitypro.cluster_certificate_authority_data
}
