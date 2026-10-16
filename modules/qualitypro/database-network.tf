resource "aws_db_subnet_group" "postgres" {
  tags       = local.project_tags
  name       = "${local.db_identifier}-private"
  subnet_ids = module.vpc.private_subnets

  lifecycle {
    precondition {
      condition     = length(toset(local.availability_zones)) >= 2
      error_message = "RDS requires private subnets in at least two Availability Zones, including for Single-AZ instances."
    }
  }
}

resource "aws_security_group" "postgres" {
  tags        = local.project_tags
  name_prefix = "${local.db_identifier}-"
  description = "Private PostgreSQL connections from EKS nodes and their pods."
  vpc_id      = module.vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "eks_to_postgres" {
  tags                         = local.project_tags
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = module.eks.node_security_group_id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  description                  = "EKS nodes and pods to private PostgreSQL."
}
