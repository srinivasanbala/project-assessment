###AWS PROVIDER###


## Get Data From VPC State File ##
data "terraform_remote_state" "vpc" {
    backend = "s3"
    config {
        bucket = "srini-techops-terraform-${var.account}"
        key = "vpcs/${var.region}.tfstate"
        region = "eu-west-1"
    }
}


data "terraform_remote_state" "core" {
    backend = "s3"
    config {
        bucket = "srini-techops-terraform-${var.account}"
        key = "core/${var.region}.tfstate"
        region = "eu-west-1"
    }
}



## poc app ##
module "app" {
  amis = "${lookup(var.amis, "${var.region}-${var.account}")}"
  appaddspace = "${var.appaddspace}"
  appaddvol = "${var.appaddvol}"
  availability_zones = "${data.terraform_remote_state.vpc.availability-zones}"
  cluster = "${var.cluster}"
  dns_name = "app-${var.cluster}-${var.environment}-${replace(var.region, "-", "")}"
  domain = "${lookup(var.resolvers, lookup(var.route53zoneid, var.environment))}"
  environment = "${var.environment}"
  instance_type = "${lookup(var.instance_types, "app")}"
  internal_subnet_ids = "${data.terraform_remote_state.vpc.internal-subnets}"
  jumper_sg = "${data.terraform_remote_state.core.jumper_sg}"
  key_name = "${var.key_name}"
  poccidrblocks = "${split(",", var.poccidrblocks)}"
  public_subnet_ids = "${data.terraform_remote_state.vpc.public-subnets}"
  region = "${var.region}"
  required_azs = "${var.appnodes}"
  required_instances = "${var.appnodes}"
  rootvolumesize = "20"
  route53zoneid = "${lookup(var.route53zoneid, var.account)}"
  source = "../modules/app"
  std_tags = "${var.std_tags}"
  vpc_cdir = "${data.terraform_remote_state.vpc.vpc_cidr}"
  vpc_id = "${data.terraform_remote_state.vpc.vpc-id}"
  enable_resource = "${var.enable-app-resource}"
}

#### poc web ##
module "web" {
  amis = "${lookup(var.amis, "${var.region}-${var.account}")}"
  web-sg = "${module.web.web-sg}"
  availability_zones = "${data.terraform_remote_state.vpc.availability-zones}"
  cluster = "${var.cluster}"
  dns_name = "web-${var.cluster}-${var.environment}-${replace(var.region, "-", "")}"
  domain = "${lookup(var.resolvers, lookup(var.route53zoneid, var.environment))}"
  environment = "${var.environment}"
  instance_type = "${lookup(var.instance_types, "publisher")}"
  internal_subnet_ids = "${data.terraform_remote_state.vpc.internal-subnets}"
  jumper_sg = "${data.terraform_remote_state.core.jumper_sg}"
  key_name = "${var.key_name}"
  poccidrblocks = "${split(",", var.poccidrblocks)}"
  webaddspace = "${var.webaddspace}"
  webaddvol = "${var.webaddvol}"
  public_subnet_ids = "${data.terraform_remote_state.vpc.public-subnets}"
  region = "${var.region}"
  required_azs = "${var.publishernodes}"
  required_instances = "${var.publishernodes}"
  rootvolumesize = "20"
  route53zoneid = "${lookup(var.route53zoneid, var.account)}"
  sites = "${var.sites}"
  source = "../modules/web"
  std_tags = "${var.std_tags}"
  vpc_cidr = "${data.terraform_remote_state.vpc.vpc_cidr}"
  vpc_id = "${data.terraform_remote_state.vpc.vpc-id}"
  enable_resource = "${var.enable-web-resource}"
}

# server - RDS instance ##
module "rds-instance" {
 source                  = "../modules/rds"
 rdsinstance-name        = "rds-instance-${var.environment}"
 storage-size            = "10"
 rdsinstance-port        = "3306"
 rdsinstance-class       = "db.t2.medium"
 rdsinstance-user        = "test"
 rdsinstance-pass        = "test123"
 rdsinstance-storagetype = "standard"
 rdsinstance-retention   = "5"
 rdsinstance-encrypt     = "true"
 std_tags                = "${var.std_tags}"
