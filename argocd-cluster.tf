# Helm supplies cluster-wide deployment permissions for all namespaces.
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
  depends_on = [module.eks, helm_release.argocd]
}
