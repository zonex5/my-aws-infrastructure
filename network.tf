data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway     = true
  single_nat_gateway     = !var.nat_gateway_per_az
  one_nat_gateway_per_az = var.nat_gateway_per_az

  map_public_ip_on_launch = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "terraform_data" "private_subnets_ready" {
  # Gate EKS subnet inputs on NAT/routing readiness without deferring the EKS
  # module's partition/account data sources and making its counts unknown.
  input      = module.vpc.private_subnets
  depends_on = [module.vpc]
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = {
    Name = "${var.cluster_name}-s3"
  }
}
