# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These variables must be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which all resources will be created"
  default     = "ap-southeast-2"
}

variable "api_gateway_domain_name" {
  description = "The dns name of the houston api gateway domain. E.g., houston.grnt.io"
  default = "houston.umccr.org"
}

variable "static_content_domain_name" {
  description = "The dns name of the static content domain. E.g., houston-static.grnt.io"
  default = "static.houston.umccr.org"
}

variable "saml_public_cert" {
  description = "The public certificate for the IdP used to authorize Houston logins. Specify a string like 'MIIDdDCCAlygAwIBAgIGAWBVpdDUMA...' here."
  default = "MIICnTCCAYUCBgFmntIfXzANBgkqhkiG9w0BAQsFADASMRAwDgYDVQQDDAdob3VzdG9uMB4XDTE4MTAyMzAyNDYwMloXDTI4MTAyMzAyNDc0MlowEjEQMA4GA1UEAwwHaG91c3RvbjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALkzoX5iRrToSTU98z03Ej1Cr4JNRNJ27kj5UuAP1EqjNeqnSSODxbxy1WNipi+p+oVCmq3HvbsfSxG9oQL4dNPPmsdmdFO/NDVySlyIL9s3ZncT+ij4jxsF7hxDcAGIFgRZFlgo1w0yjuwF8Q2vvXJd7W1Ltq2QmajChbR1/yTXttTlEw3XFgH3Pp91tzz30AiMId6C+FpUKIWw/gPnegYwbQM7XUjUetmeMfDFkxBvZHBwCqFsWoStOoOSLYi7Bjq6SKPkjwq8mNzW0DyC97q18oYOsnbsZSF1nP9VI7dR9Eeq118/g3I2XKJEY4oJbox0E3nXD43OesCC3zCDafsCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAGBdXksQv4Ip54YLRDCVHnwV5Ylnn04ICofboEERh7Xt54BSawsryM92nEhJIEA+udpCeiELJ04BJWClCqoWIB7sDTaALAScmMq0oDcuXlha6fQ+mvSPb0ZaLZGmHwTW9IZslTOf+4qDH+hkQE0SIR4jsx9r6/o1x6CkTn1JScbHOjIE7QCcaxZGgUNll3Lkuw7641jX3L+DUM+lyCSXYdl40YRng3Dfc6xsMyHwwzpdU6Ze8iK93OEWQc8GbH09oT9p/X+ZRHtyGgwA4dORn4ztJuIgn4t6TM4eSTxuuMst4GbuYorsFFhdPBDPUdDmWSbG3AR8YFTs+X38VzroTKg=="
}

variable "saml_entrypoint" {
  description = "The IdP entrypoint for the IdP used to authorize Houston logins. This is a URL that points to your IdP."
  default = "https://cbio.mdhs.unimelb.edu.au:8443/auth/realms/AWS/houston"
}

variable "saml_friendly_name" {
  description = "The friendly name for the SAML Identity Provider (e.g. 'Okta', or 'Active Directory')"
  default = "KeyCloak"
}

variable "houstoncli_entrypoint" {
  description = "The IdP entrypoint for the IdP used to authorize houstoncli logins"
  default = "https://cbio.mdhs.unimelb.edu.au:8443/auth/realms/AWS/houston_cli"
}

variable "houstoncli_public_cert" {
  description = "The public certificate for the IdP used to authorize houstoncli logins"
  default = "MIICpTCCAY0CBgFmntRmdzANBgkqhkiG9w0BAQsFADAWMRQwEgYDVQQDDAtob3VzdG9uX2NsaTAeFw0xODEwMjMwMjQ4MzFaFw0yODEwMjMwMjUwMTFaMBYxFDASBgNVBAMMC2hvdXN0b25fY2xpMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAi/BQIpKPgU/tQY0IKZf9APBg+RbTydRBs+HGaRsXFHxYmy0zEhii+s5KGgMWMGe/SdtsU8MjkokfdEySdaeN0gZ4etTKpwN0WQ/546qaPSpFL7JOsQeuL75G4e/k6mH2+rb9rbalL9zcF/efGRKVxCKBfJ720qQUQ52xm4mhZfQKS7uI8/A4FF3qwYa4rd3bO8AaNc5LJyiFXf5AVQdo9/vWTBWywBCXlDrt/FbCgZ4TSSrCvyD2BXhfG9deQnGz5S9K+TQ23fC4m2Xmj/VYUrCa8q59U1c8pVEEHW2luO1PL9dl/8wCuYwdOGQaSMNb6+TrmamqLlqrSp7HgobYlQIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQBi3AOSJmcE831JoTH4NXbSMzC6jpFMDmUYBRl8Ma/wSJvCTGztyZsPabs0eXKHTUICkidZQHEA/0B6BePg2GKwQcZxRyThdd3HjDfkit3pG6qvfm/OVn3gEsJCWgxFzQsqQZ3hqR5+VK0OumTr32BpTpvSTj3k1jTTIXg/GK9IzYHwBlOUrNRM6yBG+7OMxtj3H+HrotdtqyPpAFl7j7rxw55S9qzIlnkO5VV9nzWlg8EZeEI5CSlxoQz0QgAsM/WL7ydQ4e2XBhSY6T1QTTGLTu2O4w8Q8Ca2u7n1Y/j1JJVuoziRxKMDAdkpbuO+84w+83uXTySvrjYq0jBeEf4K"
}

variable "awsconsole_saml_entrypoint" {
  description = "The IdP entrypoint for the IdP used to authorize AWS Console logins"
  default = "https://cbio.mdhs.unimelb.edu.au:8443/auth/realms/AWS/protocol/saml/clients/amazon-aws"
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