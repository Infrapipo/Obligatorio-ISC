module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "obligatorio-isc"
  cluster_version = "1.27"


  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true #inseguro

  cluster_addons = {
    "vpc-cni" = {

      resolve_conflicts = "overwrite"
    }

    "coredns" = {
      resolve_conflicts = "overwrite"
    }

    "kube-proxy" = {
      resolve_conflicts = "overwrite"
    }

    csi = {
      resolve_conflicts = "overwrite"
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