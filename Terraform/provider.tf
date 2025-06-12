provider "aws" {
  region  = "us-east-1"
  profile = "default"
}
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.cluster.name
}
data "aws_iam_role" "eks_cluster_role" {
  name = "LabRole"
}
provider "kubectl" {
  host = aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.cluster.certificate_authority[0].data)
  token = data.aws_eks_cluster_auth.cluster.token
}