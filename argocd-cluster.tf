# Helm supplies cluster-wide reads and Argo CD's internal namespace roles.
# Application writes are granted only in the configured application namespace.
resource "kubernetes_role_v1" "argocd_deploy" {
  metadata {
    name      = "argocd-deploy"
    namespace = kubernetes_namespace_v1.application[var.application_namespace].metadata[0].name
  }
  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding_v1" "argocd_deploy" {
  metadata {
    name      = "argocd-deploy"
    namespace = kubernetes_role_v1.argocd_deploy.metadata[0].namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.argocd_deploy.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "argocd-application-controller"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "argocd-server"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
  }
  depends_on = [helm_release.argocd]
}

resource "kubernetes_secret_v1" "argocd_cluster" {
  metadata {
    name      = "in-cluster"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }
  type = "Opaque"
  data = {
    name    = "in-cluster"
    server  = "https://kubernetes.default.svc"
    project = "default"
    config  = jsonencode({ tlsClientConfig = { insecure = false } })
  }
  depends_on = [module.eks, kubernetes_role_binding_v1.argocd_deploy]
}
