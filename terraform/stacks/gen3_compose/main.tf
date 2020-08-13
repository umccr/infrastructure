terraform {
  required_version = ">= 0.12"

  backend "s3" {
    bucket = "umccr-terraform-states"
    key    = "gen3_compose/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

provider "aws" {
  version = "~> 2.64"
  region  = "ap-southeast-2"
}

locals {
  stack_name_dash = "gen3-compose"
  stack_name_us   = "gen3_compose"

  domain = "dev.umccr.org"

  default_tags = {
    "Stack"       = local.stack_name_us
    "Creator"     = "terraform"
    "Environment" = terraform.workspace
  }
}

data "aws_route53_zone" "selected" {
  name = "${local.domain}."
}

data "aws_acm_certificate" "dev_cert" {
  domain   = local.domain
  statuses = ["ISSUED"]
}

# TODO to use Main VPC
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

# TODO import EC2 instance + its security group. At the mo, we spin up EC2 instance through Console.
data "aws_instance" "gen3_compose_instance" {
  filter {
    name   = "tag:Name"
    values = ["gen3_compose"]
  }
}

resource "aws_route53_record" "gen3_rr" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "gen3.${data.aws_route53_zone.selected.name}"  # gen3.dev.umccr.org
  type    = "A"

  alias {
    evaluate_target_health = true
    name = aws_lb.gen3_compose_alb.dns_name
    zone_id = aws_lb.gen3_compose_alb.zone_id
  }
}

resource "aws_lb" "gen3_compose_alb" {
  name               = "gen3-compose-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.gen3_compose_alb_sg.id]
  subnets            = data.aws_subnet_ids.default.ids

  tags = local.default_tags
}

resource "aws_lb_listener" "frontend_http" {
  load_balancer_arn = aws_lb.gen3_compose_alb.arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port = "443"
      protocol = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.gen3_compose_alb.arn
  port = "443"
  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2016-08"
  certificate_arn = data.aws_acm_certificate.dev_cert.arn

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  depends_on = [aws_lb_target_group.app]
}

resource "aws_lb_target_group" "app" {
  name = "gen3-compose-alb-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.default_tags
}

resource "aws_lb_target_group_attachment" "gen3_compose_instance_attachment" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = data.aws_instance.gen3_compose_instance.private_ip  # using Private IP for hibernation support
  port             = 80
}

resource "aws_security_group" "gen3_compose_alb_sg" {
  name        = "gen3-compose-alb-sg"
  description = "Allow inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.default_tags
}
