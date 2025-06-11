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
