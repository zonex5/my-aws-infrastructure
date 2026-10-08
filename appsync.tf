resource "aws_appsync_api" "frontend" {
  for_each = local.frontend_event_apis

  name = each.value.name

  event_config {
    auth_provider {
      auth_type = "AWS_IAM"
    }

    connection_auth_mode {
      auth_type = "AWS_IAM"
    }

    default_publish_auth_mode {
      auth_type = "AWS_IAM"
    }

    default_subscribe_auth_mode {
      auth_type = "AWS_IAM"
    }
  }

  lifecycle {
    precondition {
      condition     = length(each.value.name) <= 50
      error_message = "The generated <namespace>-<api> AppSync API name must not exceed 50 characters."
    }

    precondition {
      condition     = length(distinct([for api in local.frontend_event_apis : api.name])) == length(local.frontend_event_apis)
      error_message = "Namespace-prefixed AppSync API names must be unique across all namespace/API combinations."
    }
  }
}

resource "aws_appsync_channel_namespace" "frontend" {
  for_each = local.frontend_event_apis

  api_id = aws_appsync_api.frontend[each.key].api_id
  name   = var.application_namespaces[each.value.namespace].appsync_event_namespace_name
}

data "aws_iam_policy_document" "frontend" {
  for_each = local.application_namespace_keys

  statement {
    sid       = "AppSyncEventConnect"
    actions   = ["appsync:EventConnect"]
    resources = [for key, api in aws_appsync_api.frontend : api.api_arn if local.frontend_event_apis[key].namespace == each.key]
  }

  statement {
    sid       = "AppSyncEventPublishAndSubscribe"
    actions   = ["appsync:EventPublish", "appsync:EventSubscribe"]
    resources = [for key, channel in aws_appsync_channel_namespace.frontend : channel.channel_namespace_arn if local.frontend_event_apis[key].namespace == each.key]
  }
}

resource "aws_iam_policy" "frontend" {
  for_each = local.application_namespace_keys

  name   = "${var.cluster_name}-${each.key}-frontend-appsync"
  policy = data.aws_iam_policy_document.frontend[each.key].json
}

resource "aws_iam_role_policy_attachment" "frontend" {
  for_each = local.application_namespace_keys

  role       = aws_iam_role.frontend[each.key].name
  policy_arn = aws_iam_policy.frontend[each.key].arn
}
