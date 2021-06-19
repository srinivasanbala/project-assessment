ariable "azs" {}
variable "cidr" {}
variable "enable_dns_hostnames" {}
variable "enable_dns_support" {}
variable "environment" {}
variable "internal_ranges" {}
variable "private_ranges" {}
variable "public_ranges" {}
variable "region" {}
variable "sid" {}
variable "acc_number" {
  type = "map"

  default = {
    dev  = "************"
    prod = "************"
  }
}
