provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.qualitypro.cluster_endpoint
  cluster_ca_certificate = base64decode(module.qualitypro.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region, "--output", "json"]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.qualitypro.cluster_endpoint
    cluster_ca_certificate = base64decode(module.qualitypro.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region, "--output", "json"]
    }
  }
}
