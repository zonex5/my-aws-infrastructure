locals {
  application_namespace_keys = toset([var.application_namespace])

  backend_service_account_name  = "backend-service-account"
  frontend_service_account_name = "frontend-service-account"

  backend_topics = {
    for name in var.backend_sns_topic_names : "${var.application_namespace}/${name}" => {
      namespace = var.application_namespace
      name      = "${var.application_namespace}-${name}"
    }
  }

  frontend_event_apis = {
    for name in var.appsync_event_api_name : "${var.application_namespace}/${name}" => {
      namespace = var.application_namespace
      name      = "${var.application_namespace}-${name}"
    }
  }

  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  common_tags = {
    Project   = var.cluster_name
    ManagedBy = "Terraform"
  }

  ingress_gateway_service_name = "istio-ingressgateway"
  ingress_http_node_port       = 30080
  ingress_status_node_port     = 31021
}
