locals {
  argocd_namespace = "argocd"
  argocd_cluster_rules = [{
    apiGroups = ["*"]
    resources = ["*"]
    verbs     = ["*"]
  }]
}

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = local.argocd_namespace
    labels = {
      "istio-injection" = "disabled"
    }
  }
  depends_on = [module.eks, helm_release.aws_load_balancer_controller, module.vpc]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "10.9.6"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name
  wait       = true
  timeout    = 600

  values = [yamlencode({
    fullnameOverride   = "argocd"
    createClusterRoles = true
    global = {
      domain = var.argocd_domain_name
    }
    configs = {
      cm = {
        url = "https://${var.argocd_domain_name}"
      }
      params = {
        "server.insecure" = true
      }
    }
    dex = {
      enabled = false
    }
    controller = {
      serviceAccount = {
        name = "argocd-application-controller"
      }
      clusterRoleRules = {
        enabled = true
        rules   = local.argocd_cluster_rules
      }
    }
    server = {
      serviceAccount = {
        name = "argocd-server"
      }
      service = {
        type = "ClusterIP"
      }
      ingress = {
        enabled = false
      }
      clusterRoleRules = {
        enabled = true
        rules   = local.argocd_cluster_rules
      }
    }
  })]
}
