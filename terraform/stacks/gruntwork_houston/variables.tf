variable "vpc_name_prefix" {
  default = "houston"
}


# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These variables must be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "api_gateway_domain_name" {
  description = "The dns name of the houston api gateway domain. E.g., houston.grnt.io"
  default = "houston.umccr.org"
}

variable "static_content_domain_name" {
  description = "The dns name of the static content domain. E.g., houston-static.grnt.io"
  default = "houston-static.umccr.org"
}

variable "saml_friendly_name" {
  description = "The friendly name for the SAML Identity Provider (e.g. 'Okta', or 'Active Directory')"
  default = "UmccrIdP"
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "api_gateway_name" {
  description = "The name of the API Gateway"
  default     = "Gruntwork Houston API"
}

variable "lambda_function_name" {
  description = "The name of the lambda function that will be created"
  default     = "HoustonExpressApp"
}

variable "sts_policy_name" {
  description = "The name of the STS policy to be created"
  default     = "houston_sts_policy"
}

variable "dynamo_db_policy_name" {
  description = "The name of the dynamodb policy to be created"
  default     = "houston_dynamodb_policy"
}

variable "iam_role_name" {
  description = "The name IAM role that will be created for the API Gateway"
  default     = "api_gateway_cloudwatch_global"
}

variable "dynamodb_table_prefix" {
  description = "The prefix used on the DynamoDB tables for this installation. You should not have to change this unless you are running multiple instances in your environment."
  default     = ""
}

variable "saml_issuer" {
  description = "The SAML issuer for the IdP used to authorize Houston logins"
  default     = "Gruntwork-Houston"
}

variable "houstoncli_issuer" {
  description = "The SAML issuer for the IdP used to authorize Houston logins"
  default     = "Gruntwork-houstoncli"
}

variable "houstoncli_aws_session_length" {
  default = 28800
}

variable "express_app_memory_size" {
  default = 2048
}

variable "log_level" {
  description = "The logging level. The possible values are error, warn, info, verbose, debug and silly"
  default     = "info"
}

variable "bitbucket_base_url" {
  description = "The base URL for your BitBucket server. Used for CI/CD with BitBucket and Jenkins."
  default     = ""
}

variable "bitbucket_username" {
  description = "The username to use to connect BitBucket server. Should be the username of a machine user. Used for CI/CD with BitBucket and Jenkins."
  default     = ""
}

variable "bitbucket_password" {
  description = "The password to use to connect BitBucket server. Should be the password of a machine user. Used for CI/CD with BitBucket and Jenkins."
  default     = ""
}

variable "jenkins_base_url" {
  description = "The base URL for your Jenkins server. Used for CI/CD with BitBucket and Jenkins."
  default     = ""
}

variable "jenkins_username" {
  description = "The username to use to connect Jenkins server. Should be the username of a machine user. Used for CI/CD with BitBucket and Jenkins."
  default     = ""
}

variable "jenkins_password" {
  description = "The password to use to connect Jenkins server. Should be the password of a machine user. Used for CI/CD with BitBucket and Jenkins."
  default     = ""
}

variable "jenkins_build_job_name" {
  description = "The name of a Jenkins build job to kick off from the Houston UI. Used for CI/CD with BitBucket and Jenkins."
  default     = ""
}

variable "vpn_roles" {
  description = "Use this variable to manage VPN access for OpenVPN servers deployed with Gruntworks package-openvpn. This variable should be a list of maps, where each map contains the fields 'name' (a name for the VPN server), 'iam_role_arn' (the ARN of an IAM Role Houston can assume to talk to the OpenVpn Server), 'aws_region' (the AWS region where the OpenVPN server is deployed), 'authorized_roles' (a list of role names that will be allowed to request VPN certificates for themselves). If you update this variable, makes ure to fill in var.num_vpn_roles too!"
  type        = "list"
  default     = []

  # Example:
  #
  # default = [
  #   {
  #     name             = "vpn-prod"
  #     iam_role_arn     = "arn:aws:iam::111111111111:role/openvpn-allow-certificate-requests-for-external-accounts"
  #     aws_region       = "us-east-1"
  #     authorized_roles = ["ops-team"]
  #   },
  #   {
  #     name             = "vpn-stage"
  #     iam_role_arn     = "arn:aws:iam::22222222222:role/openvpn-allow-certificate-requests-for-external-accounts"
  #     aws_region       = "us-west-2"
  #     authorized_roles = ["ops-team", "dev-team", "qa-team"]
  #   }
  # ]
}

variable "num_vpn_roles" {
  description = "The number of VPN roles in var.vpn_roles. We should be able to compute this automatically, but due to Terraform limitations, if var.vpn_roles references any rsources, we won't be able to. Therefore, you need to mantain this count separately."
  default     = 0
}