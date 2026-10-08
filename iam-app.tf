data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_iam_policy_document" "backend" {
  for_each = local.application_namespace_keys

  statement {
    sid       = "S3BucketMetadata"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.backend[each.key].arn]
  }

  statement {
    sid       = "S3Objects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.backend[each.key].arn}/*"]
  }

  statement {
    sid       = "CognitoUsersRead"
    actions   = ["cognito-idp:AdminGetUser", "cognito-idp:ListUsers"]
    resources = ["arn:${data.aws_partition.current.partition}:cognito-idp:${var.aws_region}:${data.aws_caller_identity.current.account_id}:userpool/${local.application_namespaces[each.key].cognito_user_pool_id}"]
  }

  dynamic "statement" {
    for_each = length(local.application_namespaces[each.key].backend_sns_topic_names) > 0 ? [1] : []

    content {
      sid       = "SnsPublish"
      actions   = ["sns:Publish"]
      resources = [for key, topic in aws_sns_topic.backend : topic.arn if local.backend_topics[key].namespace == each.key]
    }
  }

  dynamic "statement" {
    for_each = length(local.application_namespaces[each.key].backend_sns_topic_names) > 0 ? [1] : []

    content {
      sid = "SqsQueueAccess"
      actions = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:ChangeMessageVisibility",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
      ]
      resources = [for key, queue in aws_sqs_queue.backend : queue.arn if local.backend_topics[key].namespace == each.key]
    }
  }
}

resource "aws_iam_policy" "backend" {
  for_each = local.application_namespace_keys

  name   = "${var.cluster_name}-${each.key}-backend"
  policy = data.aws_iam_policy_document.backend[each.key].json
}

resource "aws_iam_role_policy_attachment" "backend" {
  for_each = local.application_namespace_keys

  role       = aws_iam_role.backend[each.key].name
  policy_arn = aws_iam_policy.backend[each.key].arn
}
