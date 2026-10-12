# Publish the existing cluster network for AWS-only consumers such as RDS.
resource "aws_ssm_parameter" "network" {
  name        = "/qualitypro/${var.project_name}/network"
  description = "Private network and EKS client security group for ${var.project_name}."
  type        = "String"
  tier        = "Standard"

  insecure_value = jsonencode({
    schema_version         = 1
    project_name           = var.project_name
    aws_account_id         = data.aws_caller_identity.current.account_id
    aws_region             = var.aws_region
    vpc_id                 = module.vpc.vpc_id
    private_subnet_ids     = module.vpc.private_subnets
    node_security_group_id = module.eks.node_security_group_id
  })

  depends_on = [module.vpc, module.eks]
}
