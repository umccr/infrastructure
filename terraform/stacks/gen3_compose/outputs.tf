output "domain_name" {
  value = aws_route53_record.gen3_rr.name
}

output "alb_dns_name" {
  value = aws_lb.gen3_compose_alb.dns_name
}
