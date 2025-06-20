terraform {
  required_providers {
    aws = {
      source  = "registry.terraform.io/hashicorp/aws"
      version = "~> 5.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.6.1"
    }
  }

  required_version = ">= 1.3.7"
}