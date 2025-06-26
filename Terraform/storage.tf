resource "aws_s3_bucket" "static_media_bucket" {
  bucket = "s3-bucket-static-media"
}
resource "aws_s3_bucket" "db_bucket" {
  bucket = "db-bucket"
}