terraform {
  required_version = "~> 0.11.6"

  backend "s3" {
    # AWS access credentials are retrieved from env variables
    bucket         = "umccr-terraform-states"
    key            = "gruntwork_houston/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  # AWS access credentials are retrieved from env variables
  region = "ap-southeast-2"
}

provider "vault" {}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# HOUSTON Requirements
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

data "aws_route53_zone" "umccr_org" {
  name = "umccr.org."
}

resource "aws_route53_zone" "houston_umccr_org" {
  name = "${var.api_gateway_domain_name}"
}

resource "aws_route53_zone" "static_houston_umccr_org" {
  name = "${var.static_content_domain_name}"
}

resource "aws_route53_record" "houston_umccr_org" {
  zone_id = "${data.aws_route53_zone.umccr_org.zone_id}"
  name    = "${var.api_gateway_domain_name}"
  type    = "NS"
  ttl     = "30"

  records = [
    "${aws_route53_zone.houston_umccr_org.name_servers.0}",
    "${aws_route53_zone.houston_umccr_org.name_servers.1}",
    "${aws_route53_zone.houston_umccr_org.name_servers.2}",
    "${aws_route53_zone.houston_umccr_org.name_servers.3}",
  ]
}

resource "aws_route53_record" "static_houston_umccr_org" {
  zone_id = "${data.aws_route53_zone.umccr_org.zone_id}"
  name    = "${var.static_content_domain_name}"
  type    = "NS"
  ttl     = "30"

  records = [
    "${aws_route53_zone.static_houston_umccr_org.name_servers.0}",
    "${aws_route53_zone.static_houston_umccr_org.name_servers.1}",
    "${aws_route53_zone.static_houston_umccr_org.name_servers.2}",
    "${aws_route53_zone.static_houston_umccr_org.name_servers.3}",
  ]
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY HOUSTON
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE HOUSTON DEPLOYMENT
# ---------------------------------------------------------------------------------------------------------------------

data "vault_generic_secret" "houston" {
  path = "kv/houston"
}

module "houston" {
  # source = "../../modules/houston"
  source = "git@github.com:gruntwork-io/houston.git//modules/houston?ref=v0.0.12"

  # LICENSING INFORMATION
  # Obtain these values from Gruntwork. Email support@gruntwork.io if you do not have your organization's values
  houston_space_center_api_key = "${data.vault_generic_secret.houston.data["api-key"]}"

  installation_id = "${data.vault_generic_secret.houston.data["installation-id"]}"

  # VPC SETTINGS
  # If you wish to run Houston in a different VPC other than the default VPC, update this code. We recommend that you
  # run Houston in a production-grade VPC, such as the one created by https://github.com/gruntwork-io/module-vpc/tree/master/modules/vpc-app
  vpc_id = "${data.aws_vpc.default.id}"

  # If you wish to run Houston in a different set of subnets other than the defaults, customize them here.
  subnet_ids = [
    "${data.aws_subnet_ids.default.ids}",
  ]

  # API GATEWAY SETTINGS
  # This module will create an API Gateway deployment for you. These properties allow you to customize that deployment.
  api_gateway_name = "${var.api_gateway_name}"

  api_gateway_description = "The API for Gruntwork Houston"

  # SETTING UP DOMAIN NAMES AND TLS CERTS FOR HOUSTON
  # Separate from this module, we expect that you will create a Route 53 Public Hosted Zone in the AWS account that runs 
  # Houston. Most likely, your DNS configuration for your root domain (e.g. acme.com) will already exist, so if you want
  # to point houston.acme.com to Houston, we recommend that you:
  #
  #   1. Create a new Route 53 Public Hosted Zone in the Houston AWS account for houston.acme.com, and note down the 
  #      authoritative name servers listed for that Route 53 Hosted Zone.  
  #
  #   2. Create a NS record for houston.acme.com in your root DNS configuration that points to the authoritative name
  #      servers for houston.acme.com
  #
  # Houston will expect two separate domain names, one for the Houston UI/API, and one for static resources in Houston 
  # such as images and javascript files. You're free to choose any name you want, but here are some suggestions:
  #
  #    api_gateway_domain_name = houston.acme.com
  #    static_content_domain_name = static.houston.acme.com
  #
  # Finally, you'll need to create a TLS certificate for each of the above domain names using Amazon Certificate Manager.
  # Because this process requires manual verification, it can't be automated. Therefore, please use the AWS Web Console
  # to create ACM certs for:
  #  
  #    - houston.acme.com
  #    - static.houston.acme.com
  #
  # ...or for whatever domain names you've chosen, and enter the ARNs of those certs below.

  api_gateway_hosted_zone_id    = "${aws_route53_record.houston_umccr_org.zone_id}"
  api_gateway_domain_name       = "${var.api_gateway_domain_name}"
  api_gateway_certificate       = "${data.aws_acm_certificate.houston_cert.arn}"
  static_content_hosted_zone_id = "${aws_route53_record.static_houston_umccr_org.zone_id}"
  static_content_domain_name    = "${var.static_content_domain_name}"
  static_content_certificate    = "${data.aws_acm_certificate.static_houston_cert.arn}"
  # This module will create all the necessary AWS resources, but gives you the option to name these resources.
  dynamodb_table_prefix = "${var.dynamodb_table_prefix}"
  lambda_function_name  = "${var.lambda_function_name}"
  iam_role_name         = "${var.iam_role_name}"
  sts_policy_name       = "${var.sts_policy_name}"
  dynamo_db_policy_name = "${var.dynamo_db_policy_name}"

  # CONFIGURING YOUR SAML IDP
  # When you configure your SAML IDP (e.g. Okta or Active Directory), you will create three SAML service providers:
  #
  #    1. AWS Console
  #    2. Houston
  #    3. Houston CLI
  #
  # See our docs (/docs/SAML-configure-idp.md) on how to configure the SAML IDP. Once you've done so, enter the 
  # appropriate values below for the Houston Service Provider (saml_public_cert, saml_entrypoint, etc.) and the 
  # Houston cli (houstoncli_public_cert, houstoncli_entrypoint, etc.). See the vars.tf definitions for additional details.

  # AWS Console SAML Service Provider values
  awsconsole_saml_entrypoint = "${data.vault_generic_secret.houston.data["awsconsole_saml_entrypoint"]}"
  # Houston SAML Service Provider values
  saml_public_cert   = "${data.vault_generic_secret.houston.data["saml_public_cert"]}"
  saml_entrypoint    = "${data.vault_generic_secret.houston.data["saml_entrypoint"]}"
  saml_friendly_name = "${var.saml_friendly_name}"
  saml_issuer        = "${var.saml_issuer}"
  # Houston CLI SAML Service Provider values
  houstoncli_public_cert        = "${data.vault_generic_secret.houston.data["houstoncli_public_cert"]}"
  houstoncli_entrypoint         = "${data.vault_generic_secret.houston.data["houstoncli_entrypoint"]}"
  houstoncli_friendly_name      = "${var.saml_friendly_name}"
  houstoncli_issuer             = "${var.houstoncli_issuer}"
  houstoncli_aws_session_length = "${var.houstoncli_aws_session_length}"
  # CONFIGURE THE IAM ROLES HOUSTON CAN ASSUME FOR OPENVPN
  # To enable Houston users to request an OpenVPN client certificate, Houston must be able to assume an IAM Role for
  # each OpenVPN Gateway in order to make the AWS API calls needed for OpenVPN operations.
  # 
  # Note that this functionality will only work when the Gruntwork OpenVPN package is deployed (https://github.com/gruntwork-io/package-openvpn)
  vpn_roles = "${var.vpn_roles}"
  # SET HOUSTON RUNTIME PREFERENCES
  express_app_memory_size = "${var.express_app_memory_size}"
  # FOR AUTOMATED TESTS ONLY
  # This is only set here so we can easily run automated tests on this code. You should NOT copy this setting into
  # your real applications.
  force_destroy_access_logs_bucket = "true"
}

# ---------------------------------------------------------------------------------------------------------------------
# PULL DATA FROM OTHER TERRAFORM TEMPLATES USING TERRAFORM REMOTE STATE
# These templates use Terraform remote state to access data from a number of other Terraform templates, all of which
# store their state in S3 buckets.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = "${data.aws_vpc.default.id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# FIND THE ACM CERTIFICATE
# If var.create_route53_entry is true, we need a custom TLS cert for our custom domain name. Here, we look for a
# cert issued by Amazon's Certificate Manager (ACM) for the domain names registered above.
# ---------------------------------------------------------------------------------------------------------------------

# Note that ACM certs for CloudFront MUST be in us-east-1!
provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

data "aws_acm_certificate" "houston_cert" {
  provider = "aws.east"

  domain = "${var.api_gateway_domain_name}"

  statuses = [
    "ISSUED",
  ]
}

data "aws_acm_certificate" "static_houston_cert" {
  provider = "aws.east"

  domain = "${var.static_content_domain_name}"

  statuses = [
    "ISSUED",
  ]
}
