resource "aws_db_instance" "default" {
  count = "${var.min_instances == "0" ? "0" : "1"}"
  name                    = "${var.rdsinstance-name}"
  allocated_storage       = "${var.storage-size}"
  engine                  = "mysql"
  engine_version          = "5.6.17"
  port                    = "${var.rdsinstance-port}"
  instance_class          = "${var.rdsinstance-class}"
  username                = "${var.rdsinstance-user}"
  password                = "${var.rdsinstance-pass}"
  storage_type            = "${var.rdsinstance-storagetype}"
  db_subnet_group_name    = "my_database_subnet_group"
  parameter_group_name    = "default.mysql5.6"
  backup_retention_period = "${var.rdsinstance-retention}" #Must be greater than 1#
  storage_encrypted       = "${var.rdsinstance-encrypt}"

  tags {
    Name = "${var.rdsinstance-name}"
    Owners = "${var.std_tags["owners"]}"
    Environment = "${var.environment}"
    App_ID = "${var.std_tags["app_id"]}"
    Cost_Allocation = "${var.std_tags["cost_allocation"]}"
    Lifecycle = "${var.std_tags["lifecycle"]}"
    ciso = "${var.std_tags["ciso"]}"
    Deployment = "${var.std_tags["deployment"]}" 
  }
}

output "rds_instance_id" {
  value = "${aws_db_instance.default.id}"
}

