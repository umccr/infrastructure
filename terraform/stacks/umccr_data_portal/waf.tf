################################################################################
# Web Security configurations

# FIXME: APIGateway v2 HttpApi does not support AWS WAF. See
#  https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html
#  Our Portal API endpoints are all secured endpoints and enforced CORS/CSRF origins protection anyway.
#  Disabled WAF resources for now, until AWS support this.

# Web Application Firewall for APIs
//resource "aws_wafregional_web_acl" "api_web_acl" {
//  depends_on = [
//    aws_wafregional_sql_injection_match_set.sql_injection_match_set,
//    aws_wafregional_rule.api_waf_sql_rule,
//  ]
//
//  name        = "dataPortalAPIWebAcl"
//  metric_name = "dataPortalAPIWebAcl"
//
//  default_action {
//    type = "ALLOW"
//  }
//
//  rule {
//    action {
//      type = "BLOCK"
//    }
//
//    priority = 1
//    rule_id  = aws_wafregional_rule.api_waf_sql_rule.id
//    type     = "REGULAR"
//  }
//
//  tags = merge(local.default_tags)
//}

# SQL Injection protection
//resource "aws_wafregional_rule" "api_waf_sql_rule" {
//  depends_on  = [aws_wafregional_sql_injection_match_set.sql_injection_match_set]
//  name        = "${local.stack_name_dash}-sql-rule"
//  metric_name = "dataPortalSqlRule"
//
//  predicate {
//    data_id = aws_wafregional_sql_injection_match_set.sql_injection_match_set.id
//    negated = false
//    type    = "SqlInjectionMatch"
//  }
//
//  tags = merge(local.default_tags)
//}

# SQL injection match set
//resource "aws_wafregional_sql_injection_match_set" "sql_injection_match_set" {
//  name = "${local.stack_name_dash}-api-injection-match-set"
//
//  # Based on the suggestion from
//  # https://d0.awsstatic.com/whitepapers/Security/aws-waf-owasp.pdf
//  sql_injection_match_tuple {
//    text_transformation = "HTML_ENTITY_DECODE"
//
//    field_to_match {
//      type = "QUERY_STRING"
//    }
//  }
//
//  sql_injection_match_tuple {
//    text_transformation = "URL_DECODE"
//
//    field_to_match {
//      type = "QUERY_STRING"
//    }
//  }
//}
