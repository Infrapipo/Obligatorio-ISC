provider "aws" {
  region  = "us-east-1"
  profile = "default"

}
provider "kubectl" {
  host                   = aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = aws_eks_cluster.cluster.certificate_authority[0].data
}