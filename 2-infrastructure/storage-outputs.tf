data "aws_ssm_parameter" "storage" {
  name            = "/qualitypro/${var.project_name}/storage"
  with_decryption = false

  lifecycle {
    postcondition {
      condition     = self.type == "String" && jsondecode(self.insecure_value).schema_version == 1
      error_message = "Storage must publish version 1 metadata as an SSM String parameter. Apply 1-storage first."
    }

    postcondition {
      condition     = jsondecode(self.insecure_value).aws_account_id == data.aws_caller_identity.current.account_id
      error_message = "Storage and infrastructure must use the same AWS account."
    }

    postcondition {
      condition     = jsondecode(self.insecure_value).aws_region == var.aws_region
      error_message = "Storage and infrastructure must use the same AWS region."
    }

    postcondition {
      condition     = toset(keys(jsondecode(self.insecure_value).s3_bucket_arn)) == local.application_namespace_keys
      error_message = "Storage must publish S3 bucket ARNs for exactly stage and prod. Apply 1-storage first."
    }
  }
}

locals {
  storage_bucket_arns = jsondecode(data.aws_ssm_parameter.storage.insecure_value).s3_bucket_arn
}
