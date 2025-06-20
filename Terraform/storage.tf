resource "aws_efs_file_system" "share-efs" {
  tags = {
    Name = "share-efs-obligatorio-isc"
  }
}