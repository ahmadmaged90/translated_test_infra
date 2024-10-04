provider "aws" {
    region = "eu-central-1"
  
}
terraform {
  backend "s3" {
    bucket = "translated-state"
    key = "test/terraform.tfstate"
    region = var.region
  }
}