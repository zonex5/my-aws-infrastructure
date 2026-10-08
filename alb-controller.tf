resource "aws_iam_policy" "aws_load_balancer_controller" {
  name   = "${var.cluster_name}-aws-load-balancer-controller"
  policy = file("${path.module}/policies/aws-load-balancer-controller.json")
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = "${var.cluster_name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

resource "kubernetes_service_account_v1" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
  }

  depends_on = [module.eks]
}

resource "aws_eks_pod_identity_association" "aws_load_balancer_controller" {
  cluster_name    = module.eks.cluster_name
  namespace       = kubernetes_service_account_v1.aws_load_balancer_controller.metadata[0].namespace
  service_account = kubernetes_service_account_v1.aws_load_balancer_controller.metadata[0].name
  role_arn        = aws_iam_role.aws_load_balancer_controller.arn

  depends_on = [aws_iam_role_policy_attachment.aws_load_balancer_controller]
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "3.4.1"
  namespace  = "kube-system"
  wait       = true
  timeout    = 600

  values = [yamlencode({
    clusterName                = module.eks.cluster_name
    region                     = var.aws_region
    vpcId                      = module.vpc.vpc_id
    enableBackendSecurityGroup = false
    serviceAccount = {
      create = false
      name   = kubernetes_service_account_v1.aws_load_balancer_controller.metadata[0].name
    }
  })]

  # Keep NAT gateways and routing available while uninstalling dependent charts
  # and finalizing controller-managed AWS resources during destroy.
  depends_on = [
    aws_eks_pod_identity_association.aws_load_balancer_controller,
    module.vpc,
  ]
}
