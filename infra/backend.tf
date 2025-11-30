terraform {
  backend "s3" {
    bucket         = "job-strapi-terraform-stat"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}

