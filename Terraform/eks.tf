module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "obligatorio-isc"
  cluster_version = "1.24"

  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  cluster_addons = {
    "vpc-cni" = {
      version = "v1.10.0-eksbuild.1"
    }
    "coredns" = {
      version = "v1.8.0-eksbuild.1"
    }
    "kube-proxy" = {
      version = "v1.24.6-eksbuild.1"
    }
  }

  eks_managed_node_groups = {
    node-group-1 = {
      desired_capacity = 1
      max_size         = 3
      min_size         = 1

      instance_type = "t3.medium"
      key_name      = "obligatorio-isc-key"

      tags = {
        Name        = "node-group-1"
        Environment = "dev"
      }
    }
  }
  
}