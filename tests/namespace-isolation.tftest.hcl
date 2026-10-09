# Plan-only tests: IAM policy statements and rendered trust, without live AWS or Kubernetes calls.
provider "aws" {
  alias                       = "offline"
  region                      = "us-east-1"
  access_key                  = "testing"
  secret_key                  = "testing"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "time" {}


variables {
  aws_region                 = "us-east-1"
  cluster_name               = "cluster-1"
  kubernetes_version         = "1.36"
  node_min_size              = 2
  node_max_size              = 2
  node_desired_size          = 2
  domain_name                = ["app.example.com", "argocd.example.com", "api.example.com"]
  argocd_domain_name         = "argocd.example.com"
  acm_certificate_arn        = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  cloudwatch_addon_version   = "v5.0.0-eksbuild.1"
  s3_bucket_name             = "test-docs"
  stage_cognito_user_pool_id = "us-east-1_testing"
  prod_cognito_user_pool_id  = "us-east-1_Prod123"
  backend_sns_topic_names    = ["notifications", "audit"]
  appsync_event_api_name     = ["events", "other"]
}

override_module {
  target = module.eks
  outputs = {
    cluster_name                       = "cluster-1"
    cluster_arn                        = "arn:aws:eks:us-east-1:123456789012:cluster/cluster-1"
    cluster_endpoint                   = "https://eks.example.test"
    cluster_certificate_authority_data = "dGVzdA=="
    node_security_group_id             = "sg-00000000000000001"
  }
}

override_module {
  target = module.vpc
  outputs = {
    vpc_id                  = "vpc-00000000000000001"
    private_subnets         = ["subnet-00000000000000001", "subnet-00000000000000002"]
    public_subnets          = ["subnet-00000000000000003", "subnet-00000000000000004"]
    private_route_table_ids = ["rtb-00000000000000001", "rtb-00000000000000002"]
  }
}

override_data {
  target = data.aws_availability_zones.available
  values = { names = ["us-east-1a", "us-east-1b"] }
}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:role/test"
    user_id    = "test"
  }
}

override_resource {
  target          = aws_iam_role.external_secrets
  override_during = plan
  values          = { arn = "arn:aws:iam::123456789012:role/cluster-1-external-secrets" }
}

override_resource {
  target          = aws_eks_pod_identity_association.external_secrets
  override_during = plan
  values          = { association_id = "a-testexternalsecrets" }
}

override_resource {
  target          = aws_s3_bucket.backend["stage"]
  override_during = plan
  values = {
    id  = "stage-test-docs-123456789012-us-east-1"
    arn = "arn:aws:s3:::stage-test-docs-123456789012-us-east-1"
  }
}

override_resource {
  target          = aws_s3_bucket.backend["prod"]
  override_during = plan
  values = {
    id  = "prod-test-docs-123456789012-us-east-1"
    arn = "arn:aws:s3:::prod-test-docs-123456789012-us-east-1"
  }
}

override_resource {
  target          = aws_iam_role.backend["stage"]
  override_during = plan
  values          = { arn = "arn:aws:iam::123456789012:role/cluster-1-stage-backend-pod" }
}

override_resource {
  target          = aws_iam_role.frontend["stage"]
  override_during = plan
  values          = { arn = "arn:aws:iam::123456789012:role/cluster-1-stage-frontend-pod" }
}

override_resource {
  target          = aws_sns_topic.backend["stage/notifications"]
  override_during = plan
  values          = { arn = "arn:aws:sns:us-east-1:123456789012:stage-notifications" }
}

override_resource {
  target          = aws_sqs_queue.backend["stage/notifications"]
  override_during = plan
  values          = { arn = "arn:aws:sqs:us-east-1:123456789012:stage-notifications-sub", id = "https://sqs.us-east-1.amazonaws.com/123456789012/stage-notifications-sub" }
}

override_resource {
  target          = aws_sns_topic.backend["stage/audit"]
  override_during = plan
  values          = { arn = "arn:aws:sns:us-east-1:123456789012:stage-audit" }
}

override_resource {
  target          = aws_sqs_queue.backend["stage/audit"]
  override_during = plan
  values          = { arn = "arn:aws:sqs:us-east-1:123456789012:stage-audit-sub", id = "https://sqs.us-east-1.amazonaws.com/123456789012/stage-audit-sub" }
}

override_resource {
  target          = aws_appsync_api.frontend["stage/events"]
  override_during = plan
  values          = { api_id = "stageevents", api_arn = "arn:aws:appsync:us-east-1:123456789012:apis/stageevents", dns = { HTTP = "stage-events.example.test", REALTIME = "stage-events-realtime.example.test" } }
}

override_resource {
  target          = aws_appsync_channel_namespace.frontend["stage/events"]
  override_during = plan
  values          = { channel_namespace_arn = "arn:aws:appsync:us-east-1:123456789012:apis/stageevents/channelNamespace/events" }
}

override_resource {
  target          = aws_appsync_api.frontend["stage/other"]
  override_during = plan
  values          = { api_id = "stageother", api_arn = "arn:aws:appsync:us-east-1:123456789012:apis/stageother", dns = { HTTP = "stage-other.example.test", REALTIME = "stage-other-realtime.example.test" } }
}

override_resource {
  target          = aws_appsync_channel_namespace.frontend["stage/other"]
  override_during = plan
  values          = { channel_namespace_arn = "arn:aws:appsync:us-east-1:123456789012:apis/stageother/channelNamespace/events" }
}

override_resource {
  target          = aws_iam_role.backend["prod"]
  override_during = plan
  values          = { arn = "arn:aws:iam::123456789012:role/cluster-1-prod-backend-pod" }
}

override_resource {
  target          = aws_iam_role.frontend["prod"]
  override_during = plan
  values          = { arn = "arn:aws:iam::123456789012:role/cluster-1-prod-frontend-pod" }
}

override_resource {
  target          = aws_sns_topic.backend["prod/notifications"]
  override_during = plan
  values          = { arn = "arn:aws:sns:us-east-1:123456789012:prod-notifications" }
}

override_resource {
  target          = aws_sqs_queue.backend["prod/notifications"]
  override_during = plan
  values          = { arn = "arn:aws:sqs:us-east-1:123456789012:prod-notifications-sub", id = "https://sqs.us-east-1.amazonaws.com/123456789012/prod-notifications-sub" }
}

override_resource {
  target          = aws_sns_topic.backend["prod/audit"]
  override_during = plan
  values          = { arn = "arn:aws:sns:us-east-1:123456789012:prod-audit" }
}

override_resource {
  target          = aws_sqs_queue.backend["prod/audit"]
  override_during = plan
  values          = { arn = "arn:aws:sqs:us-east-1:123456789012:prod-audit-sub", id = "https://sqs.us-east-1.amazonaws.com/123456789012/prod-audit-sub" }
}

override_resource {
  target          = aws_appsync_api.frontend["prod/events"]
  override_during = plan
  values          = { api_id = "prodevents", api_arn = "arn:aws:appsync:us-east-1:123456789012:apis/prodevents", dns = { HTTP = "prod-events.example.test", REALTIME = "prod-events-realtime.example.test" } }
}

override_resource {
  target          = aws_appsync_channel_namespace.frontend["prod/events"]
  override_during = plan
  values          = { channel_namespace_arn = "arn:aws:appsync:us-east-1:123456789012:apis/prodevents/channelNamespace/events" }
}

override_resource {
  target          = aws_appsync_api.frontend["prod/other"]
  override_during = plan
  values          = { api_id = "prodother", api_arn = "arn:aws:appsync:us-east-1:123456789012:apis/prodother", dns = { HTTP = "prod-other.example.test", REALTIME = "prod-other-realtime.example.test" } }
}

override_resource {
  target          = aws_appsync_channel_namespace.frontend["prod/other"]
  override_during = plan
  values          = { channel_namespace_arn = "arn:aws:appsync:us-east-1:123456789012:apis/prodother/channelNamespace/events" }
}

run "external_secrets_default_scope" {
  command = plan
  providers = {
    aws        = aws.offline
    kubernetes = kubernetes
    helm       = helm
    time       = time
  }

  assert {
    condition = (
      kubernetes_namespace_v1.external_secrets.metadata[0].name == "external-secrets" &&
      kubernetes_namespace_v1.external_secrets.metadata[0].labels["istio-injection"] == "disabled" &&
      aws_eks_pod_identity_association.external_secrets.namespace == "external-secrets" &&
      aws_eks_pod_identity_association.external_secrets.service_account == "external-secrets" &&
      !aws_eks_pod_identity_association.external_secrets.disable_session_tags &&
      yamldecode(helm_release.external_secrets.values[0]).serviceAccount.create == false &&
      yamldecode(helm_release.external_secrets.values[0]).serviceAccount.name == "external-secrets" &&
      yamldecode(helm_release.external_secrets.values[0]).installCRDs
    )
    error_message = "The operator must use its dedicated namespace and Pod Identity ServiceAccount, with CRDs installed."
  }

  assert {
    condition = (
      length(jsondecode(data.aws_iam_policy_document.external_secrets.json).Statement) == 1 &&
      toset(jsondecode(data.aws_iam_policy_document.external_secrets.json).Statement[0].Resource) == toset(["arn:aws:secretsmanager:us-east-1:123456789012:secret:stage/*", "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/*"]) &&
      toset(jsondecode(data.aws_iam_policy_document.external_secrets.json).Statement[0].Action) == toset([
        "secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret",
        "secretsmanager:GetResourcePolicy", "secretsmanager:ListSecretVersionIds"
      ])
    )
    error_message = "Default permissions must only read application-prefixed secrets, with no writes or KMS access."
  }

  assert {
    condition = jsondecode(data.aws_iam_policy_document.external_secrets_trust.json).Statement[0].Condition.StringEquals == {
      "aws:RequestTag/eks-cluster-arn"            = "arn:aws:eks:us-east-1:123456789012:cluster/cluster-1"
      "aws:RequestTag/kubernetes-namespace"       = "external-secrets"
      "aws:RequestTag/kubernetes-service-account" = "external-secrets"
    }
    error_message = "The operator role trust must be restricted to its cluster, namespace and ServiceAccount."
  }
}

run "external_secrets_custom_scope" {
  command = plan
  providers = {
    aws        = aws.offline
    kubernetes = kubernetes
    helm       = helm
    time       = time
  }
  variables {
    external_secrets_secret_arns  = ["arn:aws:secretsmanager:us-east-1:123456789012:secret:shared/database-??????"]
    external_secrets_kms_key_arns = ["arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"]
  }

  assert {
    condition = (
      length(jsondecode(data.aws_iam_policy_document.external_secrets.json).Statement) == 2 &&
      jsondecode(data.aws_iam_policy_document.external_secrets.json).Statement[0].Resource == var.external_secrets_secret_arns[0] &&
      jsondecode(data.aws_iam_policy_document.external_secrets.json).Statement[1].Action == "kms:Decrypt" &&
      jsondecode(data.aws_iam_policy_document.external_secrets.json).Statement[1].Resource == var.external_secrets_kms_key_arns[0] &&
      jsondecode(data.aws_iam_policy_document.external_secrets.json).Statement[1].Condition.StringEquals["kms:ViaService"] == "secretsmanager.us-east-1.amazonaws.com"
    )
    error_message = "Explicit secret ARNs must replace the default scope and KMS decrypt must be limited to Secrets Manager."
  }
}

run "argocd_cluster_access" {
  command = plan
  providers = {
    aws        = aws.offline
    kubernetes = kubernetes
    helm       = helm
    time       = time
  }

  assert {
    condition = (
      yamldecode(helm_release.argocd.values[0]).createClusterRoles &&
      yamldecode(helm_release.argocd.values[0]).controller.clusterRoleRules.enabled &&
      yamldecode(helm_release.argocd.values[0]).server.clusterRoleRules.enabled &&
      alltrue([for component in ["controller", "server"] :
        yamldecode(helm_release.argocd.values[0])[component].clusterRoleRules.rules == [{
          apiGroups = ["*"]
          resources = ["*"]
          verbs     = ["*"]
        }]
      ])
    )
    error_message = "Controller and server must have cluster-wide read and write permissions, independent of application_namespaces."
  }

  assert {
    condition = (
      kubernetes_secret_v1.argocd_cluster.metadata[0].name == "in-cluster" &&
      kubernetes_secret_v1.argocd_cluster.metadata[0].namespace == "argocd" &&
      kubernetes_secret_v1.argocd_cluster.metadata[0].labels["argocd.argoproj.io/secret-type"] == "cluster" &&
      nonsensitive(kubernetes_secret_v1.argocd_cluster.data) == tomap({
        name    = "in-cluster"
        server  = "https://kubernetes.default.svc"
        project = "default"
        config  = jsonencode({ tlsClientConfig = { insecure = false } })
      }) &&
      output.argocd_cluster_name == "in-cluster"
    )
    error_message = "The local deployment target must use the Kubernetes service endpoint with API TLS enabled."
  }

  assert {
    condition = (
      yamldecode(helm_release.argocd.values[0]).configs.params["server.insecure"] == true &&
      yamldecode(helm_release.argocd.values[0]).configs.cm.url == output.argocd_server_url &&
      yamldecode(helm_release.argocd.values[0]).server.service.type == "ClusterIP" &&
      yamldecode(helm_release.argocd.values[0]).server.ingress.enabled == false &&
      toset([for r in one(kubernetes_ingress_v1.app.spec).rule : r.host]) == toset(var.domain_name) &&
      alltrue([for r in one(kubernetes_ingress_v1.app.spec).rule :
        one(one(one(r.http).path).backend).service[0].name == local.ingress_gateway_service_name &&
        one(one(one(r.http).path).backend).service[0].port[0].number == 80
      ])
    )
    error_message = "Argo CD must expose an HTTP ClusterIP service, with all configured domains forwarded by the shared ALB to Istio."
  }
}
run "stage_and_prod_namespaces" {
  command = plan
  providers = {
    aws        = aws.offline
    kubernetes = kubernetes
    helm       = helm
    time       = time
  }

  assert {
    condition = (
      toset([for resource in kubernetes_namespace_v1.application : resource.metadata[0].name]) == toset(["stage", "prod"]) &&
      length(aws_s3_bucket.backend) == 2 &&
      length(aws_iam_role.backend) == 2 && length(aws_iam_role.frontend) == 2 &&
      length(aws_iam_role_policy_attachment.backend) == 2 && length(aws_iam_role_policy_attachment.frontend) == 2 &&
      length(kubernetes_service_account_v1.backend) == 2 && length(kubernetes_service_account_v1.frontend) == 2 &&
      length(aws_eks_pod_identity_association.backend) == 2 && length(aws_eks_pod_identity_association.frontend) == 2 &&
      toset([for topic in aws_sns_topic.backend : topic.name]) == toset(["stage-notifications", "stage-audit", "prod-notifications", "prod-audit"]) &&
      toset([for queue in aws_sqs_queue.backend : queue.name]) == toset(["stage-notifications-sub", "stage-audit-sub", "prod-notifications-sub", "prod-audit-sub"]) &&
      toset([for api in aws_appsync_api.frontend : api.name]) == toset(["stage-events", "stage-other", "prod-events", "prod-other"])
    )
    error_message = "Stage and prod must both receive every shared base name with their own namespace prefix."
  }

  assert {
    condition = alltrue([
      for namespace in keys(local.application_namespaces) :
      toset(flatten([for s in data.aws_iam_policy_document.backend[namespace].statement : s.resources if s.sid == "SnsPublish"])) ==
      toset(["arn:aws:sns:us-east-1:123456789012:${namespace}-notifications", "arn:aws:sns:us-east-1:123456789012:${namespace}-audit"])
    ])
    error_message = "Backend SNS grants must include both own topics and exclude every other namespace."
  }

  assert {
    condition = alltrue([
      for namespace in keys(local.application_namespaces) :
      toset(flatten([for s in data.aws_iam_policy_document.backend[namespace].statement : s.resources if s.sid == "SqsQueueAccess"])) ==
      toset(["arn:aws:sqs:us-east-1:123456789012:${namespace}-notifications-sub", "arn:aws:sqs:us-east-1:123456789012:${namespace}-audit-sub"])
    ])
    error_message = "Backend queue access must include both own queues and exclude every other namespace."
  }

  assert {
    condition = alltrue([
      for namespace in keys(local.application_namespaces) :
      toset(flatten([for s in data.aws_iam_policy_document.frontend[namespace].statement : s.resources if s.sid == "AppSyncEventConnect"])) ==
      toset(["arn:aws:appsync:us-east-1:123456789012:apis/${namespace}events", "arn:aws:appsync:us-east-1:123456789012:apis/${namespace}other"]) &&
      toset(flatten([for s in data.aws_iam_policy_document.frontend[namespace].statement : s.resources if s.sid == "AppSyncEventPublishAndSubscribe"])) ==
      toset(["arn:aws:appsync:us-east-1:123456789012:apis/${namespace}events/channelNamespace/events", "arn:aws:appsync:us-east-1:123456789012:apis/${namespace}other/channelNamespace/events"])
    ])
    error_message = "Frontend connection, publish and subscribe grants must exclude APIs and channels of the other environment."
  }

  assert {
    condition = alltrue([
      for namespace in keys(local.application_namespaces) :
      toset(flatten([for s in data.aws_iam_policy_document.backend[namespace].statement : s.resources])) == toset([
        "arn:aws:s3:::${namespace}-test-docs-123456789012-us-east-1",
        "arn:aws:s3:::${namespace}-test-docs-123456789012-us-east-1/*",
        "arn:aws:cognito-idp:us-east-1:123456789012:userpool/${namespace == "stage" ? var.stage_cognito_user_pool_id : var.prod_cognito_user_pool_id}",
        "arn:aws:sns:us-east-1:123456789012:${namespace}-notifications",
        "arn:aws:sns:us-east-1:123456789012:${namespace}-audit",
        "arn:aws:sqs:us-east-1:123456789012:${namespace}-notifications-sub",
        "arn:aws:sqs:us-east-1:123456789012:${namespace}-audit-sub",
      ]) && toset(flatten([for s in data.aws_iam_policy_document.frontend[namespace].statement : s.actions])) ==
      toset(["appsync:EventConnect", "appsync:EventPublish", "appsync:EventSubscribe"]) &&
      toset(flatten([for s in data.aws_iam_policy_document.frontend[namespace].statement : s.resources])) == toset([
        "arn:aws:appsync:us-east-1:123456789012:apis/${namespace}events",
        "arn:aws:appsync:us-east-1:123456789012:apis/${namespace}other",
        "arn:aws:appsync:us-east-1:123456789012:apis/${namespace}events/channelNamespace/events",
        "arn:aws:appsync:us-east-1:123456789012:apis/${namespace}other/channelNamespace/events",
      ])
    ])
    error_message = "No extra policy statement may grant access to another environment or add wildcard AppSync actions."
  }

  assert {
    condition = alltrue([
      for namespace in keys(local.application_namespaces) :
      aws_s3_bucket.backend[namespace].bucket == "${namespace}-test-docs-123456789012-us-east-1" &&
      toset(flatten([for s in data.aws_iam_policy_document.backend[namespace].statement : s.resources if s.sid == "S3BucketMetadata"])) ==
      toset(["arn:aws:s3:::${namespace}-test-docs-123456789012-us-east-1"]) &&
      toset(flatten([for s in data.aws_iam_policy_document.backend[namespace].statement : s.resources if s.sid == "S3Objects"])) ==
      toset(["arn:aws:s3:::${namespace}-test-docs-123456789012-us-east-1/*"]) &&
      toset(flatten([for s in data.aws_iam_policy_document.backend[namespace].statement : s.actions if s.sid == "S3BucketMetadata"])) ==
      toset(["s3:ListBucket", "s3:GetBucketLocation"]) &&
      toset(flatten([for s in data.aws_iam_policy_document.backend[namespace].statement : s.actions if s.sid == "S3Objects"])) ==
      toset(["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]) &&
      aws_s3_bucket_public_access_block.backend[namespace].bucket == aws_s3_bucket.backend[namespace].id &&
      aws_s3_bucket_public_access_block.backend[namespace].block_public_acls &&
      aws_s3_bucket_public_access_block.backend[namespace].block_public_policy &&
      aws_s3_bucket_public_access_block.backend[namespace].ignore_public_acls &&
      aws_s3_bucket_public_access_block.backend[namespace].restrict_public_buckets &&
      aws_s3_bucket_server_side_encryption_configuration.backend[namespace].bucket == aws_s3_bucket.backend[namespace].id &&
      one(one(aws_s3_bucket_server_side_encryption_configuration.backend[namespace].rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256" &&
      aws_s3_bucket_versioning.backend[namespace].bucket == aws_s3_bucket.backend[namespace].id &&
      one(aws_s3_bucket_versioning.backend[namespace].versioning_configuration).status == "Enabled" &&
      output.s3_bucket_name[namespace] == "${namespace}-test-docs-123456789012-us-east-1" &&
      output.s3_bucket_arn[namespace] == "arn:aws:s3:::${namespace}-test-docs-123456789012-us-east-1"
    ])
    error_message = "Each environment must have its own private, encrypted and versioned bucket, with backend access limited to its bucket and objects."
  }

  assert {
    condition = alltrue([
      for api in aws_appsync_api.frontend :
      one(one(api.event_config).auth_provider).auth_type == "AWS_IAM" &&
      one(one(api.event_config).connection_auth_mode).auth_type == "AWS_IAM" &&
      one(one(api.event_config).default_publish_auth_mode).auth_type == "AWS_IAM" &&
      one(one(api.event_config).default_subscribe_auth_mode).auth_type == "AWS_IAM"
    ])
    error_message = "Every AppSync API must require IAM for connecting, publishing and subscribing."
  }

  assert {
    condition = alltrue([
      for key, document in data.aws_iam_policy_document.application_pod_identity_trust :
      jsondecode(document.json).Statement[0].Principal.Service == "pods.eks.amazonaws.com" &&
      jsondecode(document.json).Statement[0].Condition.StringEquals["aws:RequestTag/eks-cluster-arn"] == "arn:aws:eks:us-east-1:123456789012:cluster/cluster-1" &&
      jsondecode(document.json).Statement[0].Condition.StringEquals["aws:RequestTag/kubernetes-namespace"] == split("/", key)[0] &&
      jsondecode(document.json).Statement[0].Condition.StringEquals["aws:RequestTag/kubernetes-service-account"] == "${split("/", key)[1]}-service-account"
    ])
    error_message = "Every role trust policy must reject a different cluster, namespace or ServiceAccount."
  }

  assert {
    condition = alltrue([
      for namespace in keys(local.application_namespaces) :
      aws_eks_pod_identity_association.backend[namespace].role_arn == "arn:aws:iam::123456789012:role/cluster-1-${namespace}-backend-pod" &&
      aws_eks_pod_identity_association.frontend[namespace].role_arn == "arn:aws:iam::123456789012:role/cluster-1-${namespace}-frontend-pod" &&
      aws_eks_pod_identity_association.backend[namespace].service_account == "backend-service-account" &&
      aws_eks_pod_identity_association.frontend[namespace].service_account == "frontend-service-account" &&
      aws_eks_pod_identity_association.backend[namespace].namespace == namespace &&
      aws_eks_pod_identity_association.frontend[namespace].namespace == namespace &&
      aws_iam_role_policy_attachment.backend[namespace].role == aws_iam_role.backend[namespace].name &&
      aws_iam_role_policy_attachment.frontend[namespace].role == aws_iam_role.frontend[namespace].name &&
      !aws_eks_pod_identity_association.backend[namespace].disable_session_tags &&
      !aws_eks_pod_identity_association.frontend[namespace].disable_session_tags
    ])
    error_message = "Pod Identity associations must bind the matching role and ServiceAccount and retain session tags."
  }

  assert {
    condition = alltrue([
      for key, policy in data.aws_iam_policy_document.backend_topic :
      one(one(one(policy.statement).principals).identifiers) == "arn:aws:iam::123456789012:role/cluster-1-${split("/", key)[0]}-backend-pod"
      ]) && alltrue([
      for key, policy in data.aws_iam_policy_document.sns_to_sqs :
      one(one(one(policy.statement).principals).identifiers) == "sns.amazonaws.com" &&
      one(one(policy.statement).principals).type == "Service" &&
      one(one(policy.statement).condition).test == "ArnEquals" &&
      one(one(policy.statement).condition).variable == "aws:SourceArn" &&
      one(one(one(policy.statement).condition).values) == aws_sns_topic.backend[key].arn &&
      aws_sns_topic_subscription.backend_sub[key].topic_arn == aws_sns_topic.backend[key].arn &&
      aws_sns_topic_subscription.backend_sub[key].endpoint == aws_sqs_queue.backend[key].arn
    ])
    error_message = "Topic policies and SNS-to-SQS delivery must preserve namespace ownership."
  }

  assert {
    condition = (
      output.backend_sns_topic_arns[keys(local.application_namespaces)[0]].notifications == "arn:aws:sns:us-east-1:123456789012:${keys(local.application_namespaces)[0]}-notifications" &&
      output.backend_sqs_queue_urls[keys(local.application_namespaces)[0]].audit == "https://sqs.us-east-1.amazonaws.com/123456789012/${keys(local.application_namespaces)[0]}-audit-sub" &&
      output.appsync_event_http_endpoint[keys(local.application_namespaces)[0]].events == "https://${keys(local.application_namespaces)[0]}-events.example.test/event" &&
      output.appsync_event_realtime_endpoint[keys(local.application_namespaces)[0]].other == "wss://${keys(local.application_namespaces)[0]}-other-realtime.example.test/event/realtime"
    )
    error_message = "Application configuration outputs must be keyed by namespace and base name."
  }
}

run "shared_platform_and_cognito_isolation" {
  command = plan
  providers = {
    aws        = aws.offline
    kubernetes = kubernetes
    helm       = helm
    time       = time
  }

  assert {
    condition = (
      toset(keys(kubernetes_namespace_v1.application)) == toset(["stage", "prod"]) &&
      alltrue([
        for namespace in ["stage", "prod"] :
        toset(flatten([for s in data.aws_iam_policy_document.backend[namespace].statement : s.resources if s.sid == "CognitoUsersRead"])) ==
        toset(["arn:aws:cognito-idp:us-east-1:123456789012:userpool/${namespace == "stage" ? var.stage_cognito_user_pool_id : var.prod_cognito_user_pool_id}"]) &&
        toset(keys(output.appsync_event_api_id[namespace])) == toset(["events", "other"]) &&
        toset(keys(output.backend_sns_topic_arns[namespace])) == toset(["notifications", "audit"]) &&
        output.s3_bucket_name[namespace] == "${namespace}-test-docs-123456789012-us-east-1" &&
        aws_eks_pod_identity_association.backend[namespace].cluster_name == "cluster-1" &&
        aws_eks_pod_identity_association.backend[namespace].namespace == namespace &&
        jsondecode(data.aws_iam_policy_document.application_pod_identity_trust["${namespace}/backend"].json).Statement[0].Condition.StringEquals["aws:RequestTag/kubernetes-namespace"] == namespace &&
        jsondecode(data.aws_iam_policy_document.application_pod_identity_trust["${namespace}/frontend"].json).Statement[0].Condition.StringEquals["aws:RequestTag/kubernetes-namespace"] == namespace
      ]) &&
      output.appsync_event_namespace_name == { stage = "events", prod = "events" } &&
      kubernetes_secret_v1.argocd_cluster.metadata[0].name == "in-cluster" &&
      helm_release.argocd.name == "argocd" &&
      helm_release.istiod.name == "istiod" &&
      helm_release.istio_ingressgateway.name == "istio-ingressgateway" &&
      kubernetes_ingress_v1.app.metadata[0].namespace == "istio-system" &&
      toset(jsondecode(data.aws_iam_policy_document.external_secrets.json).Statement[0].Resource) == toset([
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:stage/*",
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/*"
      ])
    )
    error_message = "Both environments must share one platform, use identical resource base names, and have access only to their own Cognito pool."
  }

  assert {
    condition = alltrue([
      for namespace in ["stage", "prod"] :
      output.backend_sns_topic_arns[namespace].notifications == "arn:aws:sns:us-east-1:123456789012:${namespace}-notifications" &&
      output.backend_sqs_queue_urls[namespace].audit == "https://sqs.us-east-1.amazonaws.com/123456789012/${namespace}-audit-sub" &&
      output.appsync_event_http_endpoint[namespace].events == "https://${namespace}-events.example.test/event" &&
      output.appsync_event_realtime_endpoint[namespace].other == "wss://${namespace}-other-realtime.example.test/event/realtime"
    ])
    error_message = "Outputs must expose separately prefixed resources for both stage and prod."
  }
}
run "shared_cognito_pool_allowed" {
  command = plan
  providers = {
    aws        = aws.offline
    kubernetes = kubernetes
    helm       = helm
    time       = time
  }
  variables {
    stage_cognito_user_pool_id = "us-east-1_Shared123"
    prod_cognito_user_pool_id  = "us-east-1_Shared123"
  }
  assert {
    condition = alltrue([
      for namespace in ["stage", "prod"] :
      toset(flatten([for s in data.aws_iam_policy_document.backend[namespace].statement : s.resources if s.sid == "CognitoUsersRead"])) ==
      toset(["arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_Shared123"])
    ])
    error_message = "Independently configured stage and prod IDs must support temporarily sharing one Cognito pool."
  }
}

run "reordered_lists" {
  command = plan
  providers = {
    aws        = aws.offline
    kubernetes = kubernetes
    helm       = helm
    time       = time
  }

  variables {
    s3_bucket_name          = "test-docs"
    backend_sns_topic_names = ["audit", "notifications"]
    appsync_event_api_name  = ["other", "events"]
  }
  assert {
    condition = (
      aws_sns_topic.backend["stage/notifications"].name == "stage-notifications" &&
      aws_sqs_queue.backend["stage/audit"].name == "stage-audit-sub" &&
      aws_appsync_api.frontend["stage/events"].name == "stage-events" &&
      aws_s3_bucket.backend["stage"].bucket == "stage-test-docs-123456789012-us-east-1"
    )
    error_message = "Resource addresses and names must be stable when lists are reordered."
  }
}

run "no_sns_topics" {
  command = plan
  providers = {
    aws        = aws.offline
    kubernetes = kubernetes
    helm       = helm
    time       = time
  }

  variables {
    s3_bucket_name          = "test-docs"
    backend_sns_topic_names = []
    appsync_event_api_name  = ["events", "other"]
  }
  assert {
    condition = (
      length(aws_sns_topic.backend) == 0 &&
      length(aws_sqs_queue.backend) == 0 &&
      length(aws_sns_topic_subscription.backend_sub) == 0 &&
      alltrue([
        for policy in data.aws_iam_policy_document.backend :
        alltrue([for s in policy.statement : !startswith(s.sid, "Sns") && !startswith(s.sid, "Sqs")])
      ])
    )
    error_message = "An empty SNS list must remove messaging resources and grants while preserving backend roles."
  }
}

run "queue_name_too_long" {
  command = plan
  providers = {
    aws        = aws.offline
    kubernetes = kubernetes
    helm       = helm
    time       = time
  }

  variables {
    s3_bucket_name          = "test-docs"
    backend_sns_topic_names = ["xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"]
    appsync_event_api_name  = ["events", "other"]
  }
  expect_failures = [var.backend_sns_topic_names]
}

run "bucket_suffix_already_present" {
  command = plan
  providers = {
    aws        = aws.offline
    kubernetes = kubernetes
    helm       = helm
    time       = time
  }

  variables {
    s3_bucket_name = "test-docs-123456789012-us-east-1"
  }

  assert {
    condition = (
      aws_s3_bucket.backend["stage"].bucket == "stage-test-docs-123456789012-us-east-1" &&
      aws_s3_bucket.backend["prod"].bucket == "prod-test-docs-123456789012-us-east-1"
    )
    error_message = "An existing suffix for the current account and region must not be appended twice."
  }
}

run "bucket_name_at_limit" {
  command = plan
  providers = {
    aws        = aws.offline
    kubernetes = kubernetes
    helm       = helm
    time       = time
  }

  variables {
    s3_bucket_name          = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    backend_sns_topic_names = ["notifications", "audit"]
    appsync_event_api_name  = ["events", "other"]
  }

  assert {
    condition = (
      length(aws_s3_bucket.backend["stage"].bucket) == 63
    )
    error_message = "The complete namespace-prefixed bucket name must accept the 63-character S3 boundary."
  }
}

run "bucket_name_too_long" {
  command = plan
  providers = {
    aws        = aws.offline
    kubernetes = kubernetes
    helm       = helm
    time       = time
  }

  variables {
    s3_bucket_name          = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    backend_sns_topic_names = ["notifications", "audit"]
    appsync_event_api_name  = ["events", "other"]
  }

  expect_failures = [aws_s3_bucket.backend]
}

run "api_name_too_long" {
  command = plan
  providers = {
    aws        = aws.offline
    kubernetes = kubernetes
    helm       = helm
    time       = time
  }

  variables {
    s3_bucket_name          = "test-docs"
    backend_sns_topic_names = ["notifications", "audit"]
    appsync_event_api_name  = ["xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"]
  }
  expect_failures = [var.appsync_event_api_name]
}
