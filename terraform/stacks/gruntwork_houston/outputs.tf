output "website_bucket_arn" {
  value = "${module.houston.website_bucket_arn}"
}

output "website_access_logs_bucket_arn" {
  value = "${module.houston.website_access_logs_bucket_arn}"
}

output "cloudfront_id" {
  value = "${module.houston.cloudfront_id}"
}

output "cloudfront_access_logs_bucket_arn" {
  value = "${module.houston.cloudfront_access_logs_bucket_arn}"
}

output "express_app_function_name" {
  value = "${module.houston.express_app_function_name}"
}

output "express_app_function_arn" {
  value = "${module.houston.express_app_function_arn}"
}

output "express_app_iam_role_id" {
  value = "${module.houston.express_app_iam_role_id}"
}

output "express_app_iam_role_arn" {
  value = "${module.houston.express_app_iam_role_arn}"
}

output "express_app_security_group_id" {
  value = "${module.houston.express_app_security_group_id}"
}

output "houston_domain_name" {
  value = "${module.houston.houston_domain_name}"
}

output "cmk_alias" {
  value = "${module.houston.cmk_alias}"
}