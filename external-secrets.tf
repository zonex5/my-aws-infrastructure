locals {
  external_secrets_namespace            = "external-secrets"
  external_secrets_service_account_name = "external-secrets"
  external_secrets_secret_arns = length(var.external_secrets_secret_arns) > 0 ? var.external_secrets_secret_arns : [
    "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.application_namespace}/*"
  ]
}

resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = local.external_secrets_namespace
    labels = {
      "istio-injection" = "disabled"
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_service_account_v1" "external_secrets" {
  metadata {
    name      = local.external_secrets_service_account_name
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }
}

data "aws_iam_policy_document" "external_secrets_trust" {
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
      values   = [local.external_secrets_namespace]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-service-account"
      values   = [local.external_secrets_service_account_name]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.cluster_name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_trust.json
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    sid = "ReadSecretsManagerSecrets"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = local.external_secrets_secret_arns
  }

  dynamic "statement" {
    for_each = length(var.external_secrets_kms_key_arns) > 0 ? [1] : []

    content {
      sid       = "DecryptSecretsManagerSecrets"
      actions   = ["kms:Decrypt"]
      resources = var.external_secrets_kms_key_arns

      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["secretsmanager.${var.aws_region}.${data.aws_partition.current.dns_suffix}"]
      }
    }
  }
}

resource "aws_iam_policy" "external_secrets" {
  name   = "${var.cluster_name}-external-secrets"
  policy = data.aws_iam_policy_document.external_secrets.json
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name         = module.eks.cluster_name
  namespace            = kubernetes_service_account_v1.external_secrets.metadata[0].namespace
  service_account      = kubernetes_service_account_v1.external_secrets.metadata[0].name
  role_arn             = aws_iam_role.external_secrets.arn
  disable_session_tags = false

  depends_on = [module.eks, aws_iam_role_policy_attachment.external_secrets]
}

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "2.11.0"
  namespace  = kubernetes_namespace_v1.external_secrets.metadata[0].name
  wait       = true
  timeout    = 600

  values = [yamlencode({
    installCRDs = true
    serviceAccount = {
      create = false
      name   = kubernetes_service_account_v1.external_secrets.metadata[0].name
    }
  })]

  # Service creation invokes the ALB webhook; wait until the controller is ready.
  depends_on = [
    aws_eks_pod_identity_association.external_secrets,
    helm_release.aws_load_balancer_controller,
  ]
}
