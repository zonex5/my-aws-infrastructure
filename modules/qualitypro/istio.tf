resource "kubernetes_namespace_v1" "istio_system" {
  metadata {
    name = "istio-system"
  }

  # Keep the load balancer controller and VPC egress available until all
  # controller-managed resources in this namespace have been finalized.
  depends_on = [helm_release.aws_load_balancer_controller, module.vpc]
}

resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  version    = "1.30.5"
  namespace  = kubernetes_namespace_v1.istio_system.metadata[0].name
  wait       = true
  timeout    = 600

  depends_on = [module.eks]
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = "1.30.5"
  namespace  = kubernetes_namespace_v1.istio_system.metadata[0].name
  wait       = true
  timeout    = 600

  depends_on = [helm_release.istio_base]
}

resource "helm_release" "istio_ingressgateway" {
  name       = local.ingress_gateway_service_name
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = "1.30.5"
  namespace  = kubernetes_namespace_v1.istio_system.metadata[0].name
  wait       = true
  timeout    = 600

  values = [yamlencode({
    name = local.ingress_gateway_service_name
    labels = {
      app   = local.ingress_gateway_service_name
      istio = "ingressgateway"
    }
    service = {
      type = "NodePort"
      ports = [
        {
          name       = "status-port"
          port       = 15021
          targetPort = 15021
          nodePort   = local.ingress_status_node_port
          protocol   = "TCP"
        },
        {
          name       = "http2"
          port       = 80
          targetPort = 80
          nodePort   = local.ingress_http_node_port
          protocol   = "TCP"
        }
      ]
    }
  })]

  depends_on = [helm_release.istiod]
}
