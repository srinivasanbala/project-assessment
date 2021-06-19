variable "appaddspace" { default = "200" }
variable "appaddvol" { default = "0" }
variable "cluster" {}
variable "webaddspace" { default = "200" }
variable "webaddvol" { default = "0" }

variable "appnodes" { default = "0" }
variable "webnodes" {}

variable "enable-app-resource" { default = "1" }
variable "enable-web-resource" { default = "1" }



variable "route53zoneid" {
  type = "map"
    default {
      ## zone id - domain map ##
      prod   = "*************"
      dev    = "*************"
  }
}

variable "sites" {}

variable "wildcard_cert" {
}


variable "environment" {}

variable "account" {
  default = "dev"
}

variable "resolvers" {
}


variable "std_tags" {
}

variable "required_instances" {
  default = "1"
}

variable "region" {}

## Required For Jenkins To Connect To Basket Boxes for SoapUI testing ##
## Nat Addresses From Prod Where Jenkins Sits Please ##
variable "prodeuwestnatips" {
}

## Pearson IP Ranges ##
variable "poccidrblocks" {
  default = "159.182.0.0/16,192.251.0.0/16" # Change to your IP Range!
}



variable "key_name" {}

## Autoscaling? ##
variable "asg_min" {
  default = "2"
}

variable "asg_max" {
  default = "5"
}

variable "asg_desired" {
  default = "2"
}

variable "amis" {
}

variable "vpc_cidrs" {
}

### RDS Size ###
variable "db-size" { default = "100" }
variable "rdsinstance-count" { default = "3" }
variable "rdsinstance-class" { default = "db.r3.large" }
variable "rdsinstance-storagetype" { default = "standard" }
variable "rdsinstance-retention" { default = "7" }
variable "dbversion" { default = "5.6.34" }

### Instance types ###
variable "instance_types" {
  type = "map"
  default = {
    web           = "t2.small"
    app           = "m4.large"
  }
}

variable "trustedcidrblocks" {
  type = "list"
  default = []
}
