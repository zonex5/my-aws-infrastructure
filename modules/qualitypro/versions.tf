terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.52.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      # Includes the SDK fix for empty identities after failed/slow creates.
      version = "= 3.2.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "= 2.17.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "= 0.14.2"
    }
  }

}
