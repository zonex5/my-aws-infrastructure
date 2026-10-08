data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    sid     = "AllowEksPodsToAssumeRole"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "kubernetes_namespace_v1" "application" {
  for_each = local.application_namespace_keys

  metadata {
    name = each.key
    labels = {
      "istio-injection" = "enabled"
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_service_account_v1" "backend" {
  for_each = local.application_namespace_keys

  metadata {
    name      = local.backend_service_account_name
    namespace = kubernetes_namespace_v1.application[each.key].metadata[0].name
  }
}

resource "aws_iam_role" "backend" {
  for_each = local.application_namespace_keys

  name               = "${var.cluster_name}-${each.key}-backend-pod"
  assume_role_policy = data.aws_iam_policy_document.application_pod_identity_trust["${each.key}/backend"].json
}

resource "aws_eks_pod_identity_association" "backend" {
  for_each = local.application_namespace_keys

  cluster_name    = module.eks.cluster_name
  namespace       = kubernetes_namespace_v1.application[each.key].metadata[0].name
  service_account = kubernetes_service_account_v1.backend[each.key].metadata[0].name
  role_arn        = aws_iam_role.backend[each.key].arn

  disable_session_tags = false

  depends_on = [module.eks, aws_iam_role_policy_attachment.backend]
}

resource "kubernetes_service_account_v1" "frontend" {
  for_each = local.application_namespace_keys

  metadata {
    name      = local.frontend_service_account_name
    namespace = kubernetes_namespace_v1.application[each.key].metadata[0].name
  }
}

resource "aws_iam_role" "frontend" {
  for_each = local.application_namespace_keys

  name               = "${var.cluster_name}-${each.key}-frontend-pod"
  assume_role_policy = data.aws_iam_policy_document.application_pod_identity_trust["${each.key}/frontend"].json
}

resource "aws_eks_pod_identity_association" "frontend" {
  for_each = local.application_namespace_keys

  cluster_name    = module.eks.cluster_name
  namespace       = kubernetes_namespace_v1.application[each.key].metadata[0].name
  service_account = kubernetes_service_account_v1.frontend[each.key].metadata[0].name
  role_arn        = aws_iam_role.frontend[each.key].arn

  disable_session_tags = false

  depends_on = [module.eks, aws_iam_role_policy_attachment.frontend]
}

data "aws_iam_policy_document" "application_pod_identity_trust" {
  for_each = {
    for component in ["backend", "frontend"] : "${var.application_namespace}/${component}" => {
      namespace       = var.application_namespace
      service_account = component == "backend" ? local.backend_service_account_name : local.frontend_service_account_name
    }
  }

  statement {
    sid     = "AllowMatchingEksPodIdentity"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks-cluster-arn"
      values   = [module.eks.cluster_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-namespace"
      values   = [each.value.namespace]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-service-account"
      values   = [each.value.service_account]
    }
  }
}
