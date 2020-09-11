#!/bin/bash

aws_region='ap-southeast-2'
aws_account=$(aws sts get-caller-identity | jq -r '.Account')

# To list available standard controls
# cis_sub_arn=$(aws securityhub get-enabled-standards \
#     | jq -r ".StandardsSubscriptions[].StandardsSubscriptionArn" \
#     | grep 'cis-aws-foundations')

# cis_controls=($(aws securityhub describe-standards-controls \
#     --standards-subscription-arn "$cis_sub_arn" \
#     | jq -r ".Controls[].StandardsControlArn"))

# echo ${cis_controls[@]}


# Disable certain rules for all accounts
# CIS 1.13 – Ensure MFA is enabled for the "root" account
aws securityhub update-standards-control \
    --standards-control-arn "arn:aws:securityhub:$aws_region:$aws_account:control/cis-aws-foundations-benchmark/v/1.2.0/1.13" \
    --control-status "DISABLED" \
    --disabled-reason "Using hardware MFA instead"

# CIS 2.9 - Ensure VPC flow logging is enabled in all VPCs
aws securityhub update-standards-control \
    --standards-control-arn "arn:aws:securityhub:$aws_region:$aws_account:control/cis-aws-foundations-benchmark/v/1.2.0/2.9" \
    --control-status "DISABLED" \
    --disabled-reason "TBD"

# EC2.6 - VPC flow logging should be enabled in all VPCs
aws securityhub update-standards-control \
    --standards-control-arn "arn:aws:securityhub:$aws_region:$aws_account:control/aws-foundational-security-best-practices/v/1.0.0/EC2.6" \
    --control-status "DISABLED" \
    --disabled-reason "TBD"

# Disable specific rules in member accounts if the master has them covered
# Following recommendations from AWS disble certain rules/checks
# https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-standards-cis-to-disable.html
if test "$aws_account" != '650704067584'; then

    # CIS 1.1 - Avoid the use of the "root" account
    aws securityhub update-standards-control \
        --standards-control-arn "arn:aws:securityhub:$aws_region:$aws_account:control/cis-aws-foundations-benchmark/v/1.2.0/1.1" \
        --control-status "DISABLED" \
        --disabled-reason "Covered by monitor in CloudTrail master account"

    # CIS 2.3 - Ensure the S3 bucket CloudTrail logs to is not publicly accessible
    aws securityhub update-standards-control \
        --standards-control-arn "arn:aws:securityhub:$aws_region:$aws_account:control/cis-aws-foundations-benchmark/v/1.2.0/2.3" \
        --control-status "DISABLED" \
        --disabled-reason "Following https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-standards-cis-to-disable.html"

    # CIS 2.6 - Ensure S3 bucket access logging is enabled on the CloudTrail S3 bucket
    aws securityhub update-standards-control \
        --standards-control-arn "arn:aws:securityhub:$aws_region:$aws_account:control/cis-aws-foundations-benchmark/v/1.2.0/2.6" \
        --control-status "DISABLED" \
        --disabled-reason "Following https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-standards-cis-to-disable.html"

    # CIS 2.7 - Ensure CloudTrail logs are encrypted at rest using AWS KMS CMKs
    aws securityhub update-standards-control \
        --standards-control-arn "arn:aws:securityhub:$aws_region:$aws_account:control/cis-aws-foundations-benchmark/v/1.2.0/2.7" \
        --control-status "DISABLED" \
        --disabled-reason "Following https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-standards-cis-to-disable.html"

    # CIS 3.x - Monitor CloudTrail
    for i in {1..14}; do
        # CIS 3. - 
        aws securityhub update-standards-control \
            --standards-control-arn "arn:aws:securityhub:$aws_region:$aws_account:control/cis-aws-foundations-benchmark/v/1.2.0/3.$i" \
            --control-status "DISABLED" \
            --disabled-reason "Following https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-standards-cis-to-disable.html"
    done

fi