locals {
  # Both environments share resource base names with namespace-specific grants.
  application_namespaces = {
    for namespace in ["stage", "prod"] : namespace => {
      backend_sns_topic_names      = var.backend_sns_topic_names
      appsync_event_api_name       = var.appsync_event_api_name
      appsync_event_namespace_name = var.appsync_event_namespace_name
    }
  }
  application_namespace_keys = toset(keys(local.application_namespaces))

  backend_service_account_name  = "backend-service-account"
  frontend_service_account_name = "frontend-service-account"

  backend_topics = {
    for topic in flatten([
      for namespace, config in local.application_namespaces : [
        for name in config.backend_sns_topic_names : {
          key       = "${namespace}/${name}"
          namespace = namespace
          name      = "${namespace}-${name}"
        }
      ]
    ]) : topic.key => topic
  }

  frontend_event_apis = {
    for api in flatten([
      for namespace, config in local.application_namespaces : [
        for name in config.appsync_event_api_name : {
          key       = "${namespace}/${name}"
          namespace = namespace
          name      = "${namespace}-${name}"
        }
      ]
    ]) : api.key => api
  }

  # Keep the worker AZ first so its private subnet is index 0. The second AZ
  # provides the additional subnet required by the EKS control plane and ALB.
  availability_zones = slice(distinct(concat(
    [var.node_availability_zone],
    data.aws_availability_zones.available.names
  )), 0, 2)

  common_tags = {
    Project   = var.cluster_name
    ManagedBy = "Terraform"
  }

  ingress_gateway_service_name = "istio-ingressgateway"
  ingress_http_node_port       = 30080
  ingress_status_node_port     = 31021
}
