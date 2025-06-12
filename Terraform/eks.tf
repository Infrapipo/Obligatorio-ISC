resource "aws_eks_cluster" "cluster" {
  name     = "obligatorio-isc"
  role_arn = data.aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = module.vpc.private_subnets
  }
}
resource "aws_eks_addon" "efs-csi-driver" {
  cluster_name = aws_eks_cluster.cluster.name
  addon_name   = "efs-csi-driver"
  # service_account_role_arn = data.aws_iam_role.eks_cluster_role.arn
}
resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "obligatorio-isc-workers"
  node_role_arn   = aws_eks_cluster.cluster.role_arn
  subnet_ids      = module.vpc.private_subnets

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
}
resource "aws_ecr_repository" "respository-ecr" {
  name = "obligatorio-isc-repository"
  image_tag_mutability = "MUTABLE"
  force_delete = true
}
resource "kubectl_manifest" "ingress_controller" {
  yaml_body = file("manifests/ingress-controller.yml")
}
resource "kubectl_manifest" "deployment" {
  yaml_body = file("manifests/deployments.yml")
}
resource "kubectl_manifest" "services" {
  yaml_body = file("manifests/services.yml")  
}
resource "kubectl_manifest" "ingress" {
  yaml_body = file("manifests/ingress.yml")
}