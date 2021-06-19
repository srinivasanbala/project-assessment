resource "aws_security_group" "app-auth-app-sg" {
  count       = "${var.app_enable}"
  name        = "${var.app_prefix}-sg"
  description = "${var.app_prefix}-sg"

  vpc_id = "${var.vpc_id}"

  ingress {
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = ["${var.jumper_sg}"]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["${var.jumper_sg}"]
  }
  ingress {
    from_port       = 5433
    to_port         = 5433
    protocol        = "tcp"
    security_groups = ["${aws_security_group.app-elb-sg.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name            = "${var.app_prefix}-sg"
  }
}

resource "aws_security_group" "app-elb-sg" {
  count       = "${var.app_enable}"
  name        = "${var.app_prefix}-elb-sg"
  description = "${var.app_prefix}-elb-sg"

  vpc_id = "${var.vpc_id}"

  ingress {
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = ["${var.jumper_sg}"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.pearsoncidrblocks}"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${var.pearsoncidrblocks}"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${var.pearson_remote_uk_cidr_blocks}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name            = "${var.app_prefix}-elb-sg"
  }
}

## ELB For Puppet Resources ##
resource "aws_elb" "app-elb-01-extelb" {
  count = "${var.app_enable}"
  name  = "${var.app_prefix}-elb"

  depends_on = ["aws_instance.app_instance",
    "aws_security_group.app-elb-sg",
  ]

  subnets = ["${element(split(",",var.public_subnet_ids), index(split(",", var.availability_zones), element(random_shuffle.az.result, 0)))}",
    "${element(split(",",var.public_subnet_ids), index(split(",", var.availability_zones), element(random_shuffle.az.result, 1)))}",
    "${element(split(",",var.public_subnet_ids), index(split(",", var.availability_zones), element(random_shuffle.az.result, 2)))}",
  ]

  listener {
    instance_port     = 5433
    instance_protocol = "tcp"
    lb_port           = 443
    lb_protocol       = "tcp"
  }

  listener {
    instance_port     = 80
    instance_protocol = "tcp"
    lb_port           = 80
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:5433"
    interval            = 10
  }

  instances       = ["${aws_instance.app_instance.*.id}"]
  security_groups = ["${aws_security_group.app-elb-sg.id}"]
  idle_timeout    = "${var.elb_timeout}"

  tags {
    Name            = "${var.app_prefix}-elb"
  }
}

data "template_file" "userdata" {
  count    = "${var.app_number}"
  template = "${file("${path.module}/userdata.tpl")}"

  vars {
    hostname    = "${var.app_prefix}${format("%02d", count.index + 1)}"
    resolvers   = "${var.domain}"
    role        = "app"
    environment = "${var.environment}"
    region      = "${var.region}"
  }
}

## Requires terraform 0.7.0+ ##
## Let's Get Some Random Subnets ##
resource "random_shuffle" "az" {
  count        = "${var.app_enable}"
  input        = ["${split(",", var.availability_zones)}"]
  result_count = "${var.app_number}"
}

## Spins Up an AEM author Box ##
resource "aws_instance" "app_instance" {
  count                  = "${var.app_number}"
  depends_on             = ["aws_security_group.app-auth-app-sg"]
  key_name               = "${var.key_name}"
  ami                    = "${var.amis}"
  ebs_optimized          = "${var.aem_ebs_optimized}"
  iam_instance_profile   = "${var.app_iam_instance_profile}"
  instance_type          = "${var.instance_type}"
  user_data              = "${element(data.template_file.userdata.*.rendered, count.index)}"
  subnet_id              = "${element(split(",",var.internal_subnet_ids), index(split(",", var.availability_zones), element(random_shuffle.az.result, count.index)))}"
  vpc_security_group_ids = ["${aws_security_group.app-auth-app-sg.id}"]

  #  iam_instance_profile = "${var.puppet-profile-id}"

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "${var.app_root_vol_size}"
    delete_on_termination = "false"
  }
  lifecycle {
    ignore_changes  = ["user_data", "ami"]
    prevent_destroy = false
  }
  tags {
    Name                      = "${var.app_prefix}${format("%02d", count.index + 1)}"
  }
}

## KMS Key Setup Per Region ##
resource "aws_kms_key" "keysetup" {
  count               = "${var.app_enable}"
  description         = "${var.app_prefix}-kms_key"
  enable_key_rotation = true
}

resource "aws_kms_alias" "keysetup" {
  count         = "${var.app_enable}"
  name          = "alias/${var.app_prefix}-kms_alias"
  target_key_id = "${aws_kms_key.keysetup.key_id}"
}

resource "aws_ebs_volume" "appebs_b" {
  count             = "${var.app_number}"
  depends_on        = ["aws_kms_key.keysetup"]
  availability_zone = "${element(random_shuffle.az.result, count.index)}"
  size              = "${var.appebs_b_publ_size}"
  type              = "${var.appebs_b_publ_type}"
  iops              = "${var.appebs_b_publ_iops}"
  encrypted         = "true"
  kms_key_id        = "${aws_kms_key.keysetup.arn}"

  lifecycle {
    prevent_destroy = false
    ignore_changes  = ["tags.Last-snapshot"]
  }

  tags {
    Name            = "${var.app_prefix}${format("%02d", count.index + 1)}-sdb"
  }
}

resource "aws_volume_attachment" "ebs_att_b" {
  count = "${var.app_number}"

  #  depends_on = ["aws_instance.app_instance","aws_ebs_volume.appebs_b"]
  device_name  = "/dev/sdb"
  volume_id    = "${element(aws_ebs_volume.appebs_b.*.id, count.index)}"
  instance_id  = "${element(aws_instance.app_instance.*.id, count.index)}"
  force_detach = "true"
}

## To Add Additional Volume ##
resource "aws_ebs_volume" "appebs_c" {
  count             = "${var.app_number}"
  size              = "${var.app_addspace}"
  availability_zone = "${element(random_shuffle.az.result, count.index)}"
  type              = "gp2"
  encrypted         = "true"
  kms_key_id        = "${aws_kms_key.keysetup.arn}"

  lifecycle {
    prevent_destroy = false
    ignore_changes  = ["tags.Last-snapshot"]
  }

  tags {
    Name            = "${var.app_prefix}${format("%02d", count.index + 1)}-sdc"
    Lifecycle       = "${var.std_tags["lifecycle"]}"
    ciso            = "${var.std_tags["ciso"]}"
    Deployment      = "${var.std_tags["deployment"]}"
  }
}

resource "aws_volume_attachment" "ebs_att_c" {
  count        = "${var.app_number}"
  depends_on   = ["aws_instance.app_instance"]
  device_name  = "/dev/sdc"
  volume_id    = "${element(aws_ebs_volume.appebs_c.*.id, count.index)}"
  instance_id  = "${element(aws_instance.app_instance.*.id, count.index)}"
  force_detach = "true"
}

resource "aws_route53_record" "aem_servers" {
  count   = "${var.app_number}"
  zone_id = "${var.route53zoneid}"
  name    = "${var.app_prefix}${format("%02d", count.index + 1)}"
  type    = "A"
  ttl     = "60"
  records = ["${element(aws_instance.app_instance.*.private_ip, count.index)}"]
}

resource "aws_route53_record" "aem_extelb" {
  count      = "${var.app_enable}"
  depends_on = ["aws_elb.app-elb-01-extelb"]
  zone_id    = "${var.route53zoneid}"
  name       = "${var.app_prj_prefix}"
  type       = "CNAME"

  weighted_routing_policy {
    weight = "${var.dns_cname_weight_pct}"
  }

  set_identifier = "${var.dns_cname_weighted_id}-auth"
  ttl            = "60"
  records        = ["${aws_elb.app-elb-01-extelb.dns_name}"]
}

### Outputs ##
output "auth-sg" {
  value = "${aws_security_group.app-auth-app-sg.id}"
}

output "aem-elb" {
  value = "${aws_route53_record.aem_extelb.fqdn}"
}
