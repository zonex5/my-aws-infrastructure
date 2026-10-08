output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "external_secrets_namespace" {
  description = "Namespace containing External Secrets Operator."
  value       = kubernetes_namespace_v1.external_secrets.metadata[0].name
}

output "external_secrets_pod_role_arn" {
  description = "Pod Identity IAM role used by External Secrets Operator to read Secrets Manager."
  value       = aws_iam_role.external_secrets.arn
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "EKS Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "VPC identifier."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet identifiers used by worker nodes."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet identifiers used by the ALB."
  value       = module.vpc.public_subnets
}

output "alb_dns_name" {
  description = "Controller-created ALB DNS name for the manual app CNAME."
  value       = try(kubernetes_ingress_v1.app.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "backend_service_account_name" {
  description = "Application backend ServiceAccount name."
  value       = local.backend_service_account_name
}

output "backend_pod_role_arn" {
  description = "Backend Pod Identity IAM role ARNs keyed by Kubernetes namespace."
  value       = { for namespace, role in aws_iam_role.backend : namespace => role.arn }
}

output "frontend_service_account_name" {
  description = "Frontend ServiceAccount name in the application namespace."
  value       = local.frontend_service_account_name
}

output "frontend_pod_role_arn" {
  description = "Frontend Pod Identity IAM role ARNs keyed by Kubernetes namespace."
  value       = { for namespace, role in aws_iam_role.frontend : namespace => role.arn }
}

output "application_pod_identities" {
  description = "Backend and frontend ServiceAccounts, namespace-specific IAM roles, and Pod Identity association IDs keyed by Kubernetes namespace."
  value = {
    for namespace in local.application_namespace_keys : namespace => {
      backend_service_account_name  = kubernetes_service_account_v1.backend[namespace].metadata[0].name
      frontend_service_account_name = kubernetes_service_account_v1.frontend[namespace].metadata[0].name
      backend_pod_role_arn          = aws_iam_role.backend[namespace].arn
      frontend_pod_role_arn         = aws_iam_role.frontend[namespace].arn
      backend_association_id        = aws_eks_pod_identity_association.backend[namespace].association_id
      frontend_association_id       = aws_eks_pod_identity_association.frontend[namespace].association_id
    }
  }
}

output "appsync_event_api_id" {
  description = "AppSync Event API IDs keyed by Kubernetes namespace and API base name."
  value = {
    for namespace in local.application_namespace_keys : namespace => {
      for name in var.application_namespaces[namespace].appsync_event_api_name : name => aws_appsync_api.frontend["${namespace}/${name}"].api_id
    }
  }
}

output "appsync_event_api_arn" {
  description = "AppSync Event API ARNs keyed by Kubernetes namespace and API base name."
  value = {
    for namespace in local.application_namespace_keys : namespace => {
      for name in var.application_namespaces[namespace].appsync_event_api_name : name => aws_appsync_api.frontend["${namespace}/${name}"].api_arn
    }
  }
}

output "appsync_event_http_endpoint" {
  description = "AppSync HTTP publish endpoints keyed by Kubernetes namespace and API base name."
  value = {
    for namespace in local.application_namespace_keys : namespace => {
      for name in var.application_namespaces[namespace].appsync_event_api_name : name => "https://${aws_appsync_api.frontend["${namespace}/${name}"].dns["HTTP"]}/event"
    }
  }
}

output "appsync_event_realtime_endpoint" {
  description = "AppSync IAM WebSocket endpoints keyed by Kubernetes namespace and API base name."
  value = {
    for namespace in local.application_namespace_keys : namespace => {
      for name in var.application_namespaces[namespace].appsync_event_api_name : name => "wss://${aws_appsync_api.frontend["${namespace}/${name}"].dns["REALTIME"]}/event/realtime"
    }
  }
}

output "appsync_event_namespace_name" {
  description = "AppSync channel namespace names keyed by Kubernetes application namespace."
  value       = { for namespace, config in var.application_namespaces : namespace => config.appsync_event_namespace_name }
}

output "s3_bucket_name" {
  description = "Backend S3 bucket names keyed by Kubernetes namespace."
  value       = { for namespace, bucket in aws_s3_bucket.backend : namespace => bucket.id }
}

output "s3_bucket_arn" {
  description = "Backend S3 bucket ARNs keyed by Kubernetes namespace."
  value       = { for namespace, bucket in aws_s3_bucket.backend : namespace => bucket.arn }
}

output "cloudwatch_observability_addon_version" {
  description = "Installed Amazon CloudWatch Observability EKS add-on version."
  value       = aws_eks_addon.cloudwatch_observability.addon_version
}

output "cloudwatch_control_plane_log_group" {
  description = "CloudWatch Logs group for EKS control plane logs."
  value       = "/aws/eks/${module.eks.cluster_name}/cluster"
}

output "backend_sns_topic_arns" {
  description = "Created SNS topic ARNs keyed by Kubernetes namespace and topic base name."
  value = {
    for namespace in local.application_namespace_keys : namespace => {
      for name in var.application_namespaces[namespace].backend_sns_topic_names : name => aws_sns_topic.backend["${namespace}/${name}"].arn
    }
  }
}

output "backend_sqs_queue_arns" {
  description = "Created SQS queue ARNs keyed by Kubernetes namespace and SNS topic base name."
  value = {
    for namespace in local.application_namespace_keys : namespace => {
      for name in var.application_namespaces[namespace].backend_sns_topic_names : name => aws_sqs_queue.backend["${namespace}/${name}"].arn
    }
  }
}

output "backend_sqs_queue_urls" {
  description = "Created SQS queue URLs keyed by Kubernetes namespace and SNS topic base name."
  value = {
    for namespace in local.application_namespace_keys : namespace => {
      for name in var.application_namespaces[namespace].backend_sns_topic_names : name => aws_sqs_queue.backend["${namespace}/${name}"].id
    }
  }
}

output "argocd_server_url" {
  description = "Self-hosted Argo CD UI and API URL with TLS terminated at the ALB."
  value       = "https://${var.argocd_domain_name}"
}

output "argocd_cluster_name" {
  description = "Registered Argo CD target name for Application destination.name."
  value       = kubernetes_secret_v1.argocd_cluster.metadata[0].name
}

output "argocd_cluster_server" {
  description = "Local Kubernetes API address for Application destination.server."
  value       = "https://kubernetes.default.svc"
}
