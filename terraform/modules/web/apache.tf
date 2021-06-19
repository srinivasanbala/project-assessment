resource "aws_security_group" "web-sg" {
  count =       "${var.web_enable}"
  name =        "${var.web_prefix}-sg"
  description = "${var.web_prefix}-sg"

  vpc_id = "${var.vpc_id}"

  tags {
    Name            = "${var.web_prefix}-sg"
    Lifecycle       = "${var.std_tags["lifecycle"]}"
    Environment     = "${var.std_tags["t_environment"]}"
  }
}

resource "aws_security_group_rule" "egress-all-to-all-webpub-app" {
  count = "${var.web_enable}"
  security_group_id = "${aws_security_group.web-sg.id}"
  type = "egress"
  protocol = "-1"
  from_port = 0
  to_port = 0
  cidr_blocks = [ "0.0.0.0/0"]
}


resource "aws_security_group_rule" "ingress-icmp-from-jumper-webpub-app" {
  count = "${var.web_enable}"
  security_group_id = "${aws_security_group.web-sg.id}"
  type = "ingress"
  protocol = "icmp"
  from_port = -1
  to_port = -1
  source_security_group_id =  "${var.jumper_sg}"
}


resource "aws_security_group_rule" "ingress-ssh-from-jumper-webpub-app" {
  count = "${var.web_enable}"
  security_group_id = "${aws_security_group.web-sg.id}"
  type = "ingress"
  protocol = "tcp"
  from_port = 22
  to_port = 22
  source_security_group_id =  "${var.jumper_sg}"
}


resource "aws_security_group_rule" "ingress-http-from-publishers-webpub-app" {
  count = "${var.web_enable}"
  security_group_id = "${aws_security_group.web-sg.id}"
  type = "ingress"
  protocol = "tcp"
  from_port = 80
  to_port = 80
  source_security_group_id =  "${var.publ-sg}"
}

resource "aws_security_group_rule" "ingress-http-from-elb-webpub-app" {
  count = "${var.web_enable}"
  security_group_id = "${aws_security_group.web-sg.id}"
  type = "ingress"
  protocol = "tcp"
  from_port = 80
  to_port = 80
  source_security_group_id =  "${aws_security_group.web-elb-sg.id}"
}


resource "aws_security_group_rule" "ingress-https-from-elb-webpub-app" {
  count = "${var.web_enable}"
  security_group_id = "${aws_security_group.web-sg.id}"
  type = "ingress"
  protocol = "tcp"
  from_port = 443
  to_port = 443
  source_security_group_id =  "${aws_security_group.web-elb-sg.id}"
}


resource "aws_security_group" "web-elb-sg" {
  count = "${var.web_enable}"
  depends_on = ["aws_instance.webpub_instance"]
  name        = "${var.disp_prefix}-elb-sg"
  description = "${var.disp_prefix}-elb-sg"

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
    from_port = 80
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [ "${var.trustedcidrblocks}" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name            = "${var.web_prefix}-elb-sg"
  }
}

## ELB For Puppet Resources ##
resource "aws_elb" "webpub-elb-01-extelb" {
  count = "${var.web_enable}"
  depends_on=["aws_instance.webpub_instance","aws_security_group.web-elb-sg"]
  name = "${var.disp_prefix}-elb"

  # Set ELB accross all possible zones
  subnets = ["${split(",", var.public_subnet_ids)}"]

  listener {
    instance_port = 443
    instance_protocol = "https"
    lb_port = 443
    lb_protocol = "https"
    ssl_certificate_id = "${var.ssl_arn}"
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
    target              = "TCP:443"
    interval            = 10
  }

  instances       = ["${aws_instance.webpub_instance.*.id}"]
  security_groups = ["${aws_security_group.web-elb-sg.id}"]

  tags {
    Name            = "${var.web_prefix}-elb"
  }
}

data "template_file" "webpubuserdata" {
  template = "${file("${path.module}/userdata.tpl")}"
  count    = "${var.web_number}"

  vars {
    hostname    = "${var.web_prefix}${format("%02d", count.index + 1)}"
    resolvers   = "${var.domain}"
    role        = "web"
    environment = "${var.environment}"
    region      = "${var.region}"
  }
}

## Spins Up A web Box ##
resource "aws_instance" "webpub_instance" {
  count                  = "${var.web_number}"
  depends_on 		 = ["aws_security_group.web-sg","aws_ebs_snapshot.encrypted_snapshot"]
  key_name               = "${var.key_name}"
  ami                    = "${var.amis}"
  ebs_optimized          = "${var.disp_ebs_optimized}"
  instance_type          = "${var.webpub_type}"
  user_data              = "${element(data.template_file.webpubuserdata.*.rendered, count.index)}"
  subnet_id              = "${element(split(",",var.internal_subnet_ids), index(split(",", var.availability_zones), element(random_shuffle.az.result, count.index)))}"
  vpc_security_group_ids = ["${aws_security_group.web-sg.id}"]

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "${var.disp_root_vol_size}"
    delete_on_termination = "false"
  }

  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_size           = "${var.disp_addspace}"
    volume_type           = "${var.aemebs_b_disp_type}"
    iops                  = "${var.aemebs_b_disp_iops}"
    snapshot_id           = "${aws_ebs_snapshot.encrypted_snapshot.id}"
    delete_on_termination = "false"
  }

  lifecycle {
    ignore_changes  = ["user_data", "tags.Last-snapshot", "ami",]
    prevent_destroy = false
  }

  tags {
    Name                      = "${var.web_prefix}${format("%02d", count.index + 1)}"
    Lifecycle       = "${var.std_tags["lifecycle"]}"
    Role            = "webpub"
  }
}

resource "aws_route53_record" "webpub_servers" {
  count   = "${var.web_number}"
  zone_id = "${var.route53zoneid}"
  name    = "${var.web_prefix}${format("%02d", count.index + 1)}"
  type    = "A"
  ttl     = "60"
  records = ["${element(aws_instance.webpub_instance.*.private_ip, count.index)}"]
}

resource "aws_route53_record" "webpub_extelb" {
  count = "${var.web_enable}"
  depends_on = ["aws_elb.webpub-elb-01-extelb"]
  zone_id = "${var.route53zoneid}"
  name = "${var.web_prj_prefix}"
  type    = "CNAME"
  weighted_routing_policy { weight = "${var.dns_cname_weight_pct}" }
  set_identifier = "${var.dns_cname_weighted_id}-disp"
  ttl     = "60"
  records = ["${aws_elb.webpub-elb-01-extelb.dns_name}"]
}

## DNS For Hosted Sites In Env ##
resource "aws_route53_record" "sites" {
  count = "${var.web_enable}"
  depends_on = ["aws_elb.webpub-elb-01-extelb"]
  zone_id = "${var.route53zoneid}"
  name    = "${element(split(",",var.sites), count.index)}"
  type    = "CNAME"
  weighted_routing_policy { weight = "${var.dns_cname_weight_pct}" }
  set_identifier = "${var.dns_cname_weighted_id}"
  ttl     = "60"
  records = [ "${var.web_prj_prefix}.${var.domain}" ]
}

## DNS For Hosted Sites In Env ##
resource "aws_route53_record" "secure_sites" {
  count          = "${var.web_enable}"
  depends_on     = ["aws_elb.webpub-elb-01-extelb"]
  zone_id        = "${var.route53zoneid}"
  name           = "secure.${element(split(",",var.sites), count.index)}"
  type           = "CNAME"
  weighted_routing_policy {
  weight         = "${var.dns_cname_weight_pct}"
  }
  set_identifier = "${var.dns_cname_weighted_id}"
  ttl            = "60"
  records        = [ "${var.disp_prj_prefix}.${var.domain}" ]
}

resource "random_shuffle" "az" {
  count = "${var.web_enable}"
  input        = ["${split(",", var.availability_zones)}"]
  result_count = "${var.web_number}"
}

resource "aws_ebs_snapshot" "encrypted_snapshot" {
  count = "${var.web_enable}"
  volume_id = "${aws_ebs_volume.encrypted.id}"

  lifecycle {
    ignore_changes = ["volume_id"]
  }
}
resource "aws_ebs_volume" "encrypted" {
  count = "${var.web_enable}"
  availability_zone = "${element(split(",",var.availability_zones), 1 )}"
  size              = 1
  type              = "gp2"
  encrypted         = "true"
  kms_key_id        = "${aws_kms_key.keysetup.arn}"

  lifecycle {
    prevent_destroy = false
  }

  tags {
    Name = "${var.web_prefix}${format("%02d", count.index + 1)}-encrypted-sdb"
    Lifecycle = "${var.std_tags["lifecycle"]}"
  }
}

## KMS Key Setup Per Region ##
resource "aws_kms_key" "keysetup" {
  count = "${var.web_enable}"
  description = "${var.web_prefix}-kms_key"
  enable_key_rotation = true
}

resource "aws_kms_alias" "keysetup" {
  count = "${var.web_enable}"
  name = "alias/${var.web_prefix}-kms_alias"
  target_key_id = "${aws_kms_key.keysetup.key_id}"
}

### Outputs ##
output "webpub-sg" {
  value = "${aws_security_group.web-sg.id}"
}

output "webpub-elb" {
  value = "${aws_route53_record.aem_webpub_extelb.fqdn}"
}
