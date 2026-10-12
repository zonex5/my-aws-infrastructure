resource "aws_sns_topic" "backend" {
  for_each = local.backend_topics

  name = each.value.name

  lifecycle {
    precondition {
      condition     = length(distinct([for topic in local.backend_topics : topic.name])) == length(local.backend_topics)
      error_message = "Namespace-prefixed SNS topic names must be unique across all namespace/topic combinations."
    }
  }
}

resource "aws_sqs_queue" "backend" {
  for_each = local.backend_topics

  name                    = "${each.value.name}-sub"
  sqs_managed_sse_enabled = true

  lifecycle {
    precondition {
      condition     = length("${each.value.name}-sub") <= 80
      error_message = "The generated <namespace>-<topic>-sub SQS queue name must not exceed 80 characters."
    }
  }
}

data "aws_iam_policy_document" "backend_topic" {
  for_each = local.backend_topics

  statement {
    sid       = "AllowNamespaceBackendToPublish"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.backend[each.key].arn]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.backend[each.value.namespace].arn]
    }
  }
}

resource "aws_sns_topic_policy" "backend" {
  for_each = local.backend_topics

  arn    = aws_sns_topic.backend[each.key].arn
  policy = data.aws_iam_policy_document.backend_topic[each.key].json
}

data "aws_iam_policy_document" "sns_to_sqs" {
  for_each = local.backend_topics

  statement {
    sid       = "AllowSnsTopicToSendMessages"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.backend[each.key].arn]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.backend[each.key].arn]
    }
  }
}

resource "aws_sqs_queue_policy" "sns_to_sqs" {
  for_each = local.backend_topics

  queue_url = aws_sqs_queue.backend[each.key].id
  policy    = data.aws_iam_policy_document.sns_to_sqs[each.key].json
}

resource "aws_sns_topic_subscription" "backend_sub" {
  for_each = local.backend_topics

  topic_arn            = aws_sns_topic.backend[each.key].arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.backend[each.key].arn
  raw_message_delivery = false

  depends_on = [aws_sqs_queue_policy.sns_to_sqs]
}
