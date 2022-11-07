# UMCCR Data Portal Stack

This stack deploys the AWS resources for the UMCCR data portal.

## Quickstart

1. For a fresh start, **prepare prerequisites** as described section below
2. Then _rinse and spin_ terraform as usual
    ```bash
    $ terraform init .
    $ terraform workspace list
    $ terraform workspace select dev
    $ terraform plan
    $ terraform apply
    $ terraform output -json > out.json # Optional
    ```

## Prerequisites

Need to create deployment environment specific secret parameters as follows.

- Django Secret Key: `/data_portal/backend/django_secret_key`
- RDS DB Username: `/data_portal/[dev|stg|prod]/rds_db_username`
- RDS DB Password: `/data_portal/[dev|stg|prod]/rds_db_password`
- Google LIMS Spreadsheet ID: `/umccr/google/drive/lims_sheet_id`
- Google LIMS Service Account JSON: `/umccr/google/drive/lims_service_account_json`
- Lab Tracking Sheet ID: `/umccr/google/drive/tracking_sheet_id`

e.g. For `dev` environment
```
aws ssm put-parameter --name '/data_portal/backend/django_secret_key' --type "SecureString" --value '<Django Secret Key>'
```

You can check existing parameter, example as follows.
```
aws ssm get-parameter --name '/data_portal/dev/rds_db_password' --with-decryption | jq -r .Parameter.Value
```

### Additional Backend Dependencies

Portal UI integrate with additional backends. The following SSM parameter are expected.

- Htsget Domain: `/htsget/domain`
- GPL Submit Job: `/gpl/submit_job_lambda_fn_url`
- GPL Submit Job Manual: `/gpl/submit_job_manual_lambda_fn_url`

## Post Deployment

### Certificate Validation

If `var.alias_domain` is configured for additional domain to alias `var.base_domain`, and the `var.alias_domain`'s Route53 hosted zone is in different account (e.g. bastion), then terraform script will just create/request the certificate in ACM and, it will be pending DNS validation. Please follow up with [DNS certificate validation through ACM Console UI](https://aws.amazon.com/blogs/security/easier-certificate-validation-using-dns-with-aws-certificate-manager/) to respective Route53 zones. See also notes on `var.certificate_validation` and `client_cert_dns` for further details.

## Destroy

> * Before tear down terraform stack, follow [API Serverless stack Destroy](https://github.com/umccr/data-portal-apis#destroy) section to remove Serverless stack, first!
> * Then, run `terraform destroy`

#### Caveat 

Terraform and AWS in general, when recycling resources like ACM certificate with associated CloudFront distribution, S3 bucket with versioned-objects and, RDS snapshots or RDS instance with delete protection, then terraform destroy may fail. Because these resources still hold association with their counterpart resources -- which, for some reason, have not clear yet or this is by-design protection. In this case, purge/untangle these resources through Console UI, then re-run terraform destroy until it has become success. For example:

```
Error: Error applying plan:

1 error occurred:
	* aws_s3_bucket.client_bucket (destroy): 1 error occurred:
	* aws_s3_bucket.client_bucket: error deleting S3 Bucket (umccr-data-portal-client-dev): BucketNotEmpty: The bucket you tried to delete is not empty
	status code: 409, request id: D2156698BB748933, host id: l+Z1DMnaCeFqQtaXRufoLt1wpO3a7VMi7KQXXmigZuNbYnV9I73uqkDUNzyGHlAp0xYeTb+9XaY=
```
