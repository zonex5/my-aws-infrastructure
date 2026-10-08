resource "aws_vpc_security_group_ingress_rule" "istio_http_node_port" {
  security_group_id = module.eks.node_security_group_id
  cidr_ipv4         = var.vpc_cidr
  from_port         = local.ingress_http_node_port
  to_port           = local.ingress_http_node_port
  ip_protocol       = "tcp"
  description       = "ALB to Istio ingress HTTP NodePort"
}

resource "aws_vpc_security_group_ingress_rule" "istio_readiness_node_port" {
  security_group_id = module.eks.node_security_group_id
  cidr_ipv4         = var.vpc_cidr
  from_port         = local.ingress_status_node_port
  to_port           = local.ingress_status_node_port
  ip_protocol       = "tcp"
  description       = "ALB to Istio readiness NodePort"
}

resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = "app"
    namespace = kubernetes_namespace_v1.istio_system.metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/scheme"                    = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"               = "instance"
      "alb.ingress.kubernetes.io/certificate-arn"           = var.acm_certificate_arn
      "alb.ingress.kubernetes.io/listen-ports"              = jsonencode([{ HTTP = 80 }, { HTTPS = 443 }])
      "alb.ingress.kubernetes.io/ssl-redirect"              = "443"
      "alb.ingress.kubernetes.io/healthcheck-protocol"      = "HTTP"
      "alb.ingress.kubernetes.io/healthcheck-path"          = "/healthz/ready"
      "alb.ingress.kubernetes.io/healthcheck-port"          = tostring(local.ingress_status_node_port)
      "alb.ingress.kubernetes.io/healthcheck-success-codes" = "200"
      "alb.ingress.kubernetes.io/subnets"                   = join(",", module.vpc.public_subnets)
    }
  }

  spec {
    ingress_class_name = "alb"

    dynamic "rule" {
      for_each = toset(var.domain_name)
      content {
        host = rule.value

        http {
          path {
            path      = "/"
            path_type = "Prefix"

            backend {
              service {
                name = local.ingress_gateway_service_name

                port {
                  number = 80
                }
              }
            }
          }
        }
      }
    }
  }

  wait_for_load_balancer = true

  depends_on = [
    module.vpc,
    helm_release.istio_ingressgateway,
    helm_release.aws_load_balancer_controller,
    aws_vpc_security_group_ingress_rule.istio_http_node_port,
    aws_vpc_security_group_ingress_rule.istio_readiness_node_port
  ]
}
