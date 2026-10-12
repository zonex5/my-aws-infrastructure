data "aws_eks_addon_version" "cloudwatch" {
  count              = var.cloudwatch_addon_version == null ? 1 : 0
  addon_name         = "amazon-cloudwatch-observability"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

resource "aws_iam_role" "cloudwatch_agent" {
  name               = "${var.cluster_name}-cloudwatch-agent"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.cloudwatch_agent.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_xray" {
  role       = aws_iam_role.cloudwatch_agent.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "amazon-cloudwatch-observability"
  addon_version = coalesce(var.cloudwatch_addon_version, try(data.aws_eks_addon_version.cloudwatch[0].version, null))

  pod_identity_association {
    service_account = "cloudwatch-agent"
    role_arn        = aws_iam_role.cloudwatch_agent.arn
  }

  configuration_values = jsonencode({
    manager = {
      applicationSignals = {
        autoMonitor = {
          monitorAllServices = false
        }
      }
    }
  })

  # Service creation invokes the ALB webhook; wait until its controller is ready.
  depends_on = [
    aws_iam_role_policy_attachment.cloudwatch_agent,
    aws_iam_role_policy_attachment.cloudwatch_xray,
    helm_release.aws_load_balancer_controller,
    module.eks
  ]
}
