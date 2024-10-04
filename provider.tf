provider "aws" {
    region = var.region
  
}
terraform {
  backend "s3" {
    bucket = "translated-state"
    key = "test/terraform.tfstate"
    region = "eu-central-1"
  }
}