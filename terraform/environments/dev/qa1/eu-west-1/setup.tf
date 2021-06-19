terraform {
  required_version = "= 0.9.11"
  backend "s3" {
    bucket = "srini-techops-terraform-dev"
    key    = "core/eu-west-1.tfstate"
    region = "eu-west-1"
    lock_table = "terraformLocks"
  }
}

# Let's keep the provider declaration heer so it will raise an error if we don't create this file
provider "aws" {
  region = "eu-west-1"
}
