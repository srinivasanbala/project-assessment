variable "pod" {}
variable "app_enable" {}
variable "app_number" {}
variable "app_prefix" {}
variable "app_prj_prefix" {}

variable "app_root_vol_size" {
  default = "20"
}

variable "app_addspace" {
  default = "200"
}

variable "app_addvol" {
  default = "0"
}

variable "elb_timeout" {
  default = "180"
}

variable "environment" {}
variable "region" {}
variable "region_acronym" {}

# not needed (?) adding only for the predev4,5 DNS switch
variable "dns_cname_weighted_id" {}

variable "dns_cname_weight_pct" {}
variable "appebs_b_publ_type" {}
variable "appebs_b_publ_iops" {}
variable "appebs_b_publ_size" {}
variable "app_ebs_optimized" {}


variable "app_iam_instance_profile" {}

variable "amis" {}
variable "availability_zones" {}
variable "domain" {}
variable "instance_type" {}
variable "internal_subnet_ids" {}
variable "jumper_sg" {}
variable "key_name" {}

variable "kpmgcidrblocks" {
  type = "list"
}

variable "public_subnet_ids" {}
variable "puppet-elb" {}
variable "route53zoneid" {}

variable "std_tags" {
  type = "map"

  default = {}
}

variable "vpc_cdir" {}
variable "vpc_id" {}
