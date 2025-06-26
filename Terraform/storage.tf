resource "aws_efs_file_system" "share-efs" {
  tags = {
    Name = "static/media-efs"
  }
}
resource "aws_efs_file_system" "postgres-efs" {
  tags = {
    Name = "postgres-efs"
  }
}