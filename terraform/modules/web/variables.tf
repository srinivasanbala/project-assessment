variable "web_enable" {}
variable "web_number" {}
variable "web_prefix" {}
variable "web_prj_prefix" {}
variable "web_root_vol_size" { default = "20" }
variable "web_addspace" { default = "300" }
variable "web_addvol" { default = "300" }
variable "web_ebs_optimized" {}
variable "environment" {}
variable "region" {}
variable "region_acronym" {}
variable "amis" {}
variable "availability_zones" {}
variable "domain" {}
variable "instance_type" {}
variable "aemebs_b_web_type" {}
variable "aemebs_b_web_iops" {}
variable "internal_subnet_ids" {}
variable "jumper_sg" {}
variable "key_name" {}
variable "kpmgcidrblocks" { type = "list" }
variable "public_subnet_ids" {}
variable "puppet-elb" {}
variable "route53zoneid" {}
variable "std_tags" { type = "map" default = {} }
variable "vpc_cdir" {}
variable "vpc_id" {}

# needed for the predev4,5 DNS switch
variable "dns_cname_weighted_id" {}
variable "dns_cname_weight_pct" {}
variable "apache_dns_name" {}
variable "auth-sg" {}
variable "publ-sg" {}
variable "dns_name" {}
variable "webpub_type" {}
variable "pubkey" {}
variable "sites" {}
variable "ssl_arn" {}
variable "trustedcidrblocks" { type = "list" default = [] }
