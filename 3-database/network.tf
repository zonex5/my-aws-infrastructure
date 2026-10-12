data "aws_ssm_parameter" "network" {
  name            = "/qualitypro/${var.project_name}/network"
  with_decryption = false

  lifecycle {
    postcondition {
      condition     = self.type == "String" && jsondecode(self.insecure_value).schema_version == 1
      error_message = "Infrastructure must publish version 1 network metadata as an SSM String. Apply 2-infrastructure first."
    }
    postcondition {
      condition     = jsondecode(self.insecure_value).project_name == var.project_name && jsondecode(self.insecure_value).aws_account_id == data.aws_caller_identity.current.account_id && jsondecode(self.insecure_value).aws_region == var.aws_region
      error_message = "Database must use network metadata from the same project, AWS account and region."
    }
    postcondition {
      condition     = length(toset(jsondecode(self.insecure_value).private_subnet_ids)) >= 2
      error_message = "Infrastructure must publish at least two distinct private subnets."
    }
  }
}

data "aws_subnet" "database" {
  for_each = toset(local.network.private_subnet_ids)
  id       = each.value

  lifecycle {
    postcondition {
      condition     = self.vpc_id == local.network.vpc_id && !self.map_public_ip_on_launch
      error_message = "Database subnets must belong to the published VPC and must not assign public IPs."
    }
  }
}

data "aws_security_group" "eks_nodes" {
  id = local.network.node_security_group_id

  lifecycle {
    postcondition {
      condition     = self.vpc_id == local.network.vpc_id
      error_message = "The EKS client security group must belong to the published VPC."
    }
  }
}

resource "aws_db_subnet_group" "postgres" {
  name       = "${local.db_identifier}-private"
  subnet_ids = local.network.private_subnet_ids

  lifecycle {
    precondition {
      condition     = length(toset([for subnet in data.aws_subnet.database : subnet.availability_zone])) >= 2
      error_message = "RDS requires private subnets in at least two Availability Zones, including for Single-AZ instances."
    }
  }
}

resource "aws_security_group" "postgres" {
  name_prefix = "${local.db_identifier}-"
  description = "Private PostgreSQL connections from EKS nodes and their pods."
  vpc_id      = local.network.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "eks_to_postgres" {
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = data.aws_security_group.eks_nodes.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  description                  = "EKS nodes and pods to private PostgreSQL."
}
