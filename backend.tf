terraform {
   backend "s3" {
      bucket = "s3-backend-vishnu"
      key    = "terraform-state"
      region = "${var.aws_region}"
   }
}
