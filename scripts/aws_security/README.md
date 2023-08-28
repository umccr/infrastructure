# AWS Security Hub Control Script

The purpose of this script is to disable AWS Security Hub Controls not relevant to UMCCR's workloads across all UMCCR accounts.

Affected AWS Accounts:
(Note: The provided control will be disabled across all of these accounts)

- agha
- aws_onboarding
- Databricks
- hartwig
- Oliver Hofmann
- Tothill
- umccr_bastion
- umccr_development
- umccr_nf_tower
- umccr_production
- umccr_staging

### 1. Copy the AWS Config file to a local directory

The [./config](./config) should be copied to your `/.aws/config` file so the script would refer to the same AWS Profiles.

To open your config file, paste this to your terminal.

```#!/bin/bash
cd && cd ./.aws && open config
```

### 2. Login to all these profiles

Currently, we are not considering having a role from the root account to modify other accounts. So we would need
to modify this per account level. The `./aws-login.sh` should log you into all accounts (listed above) associated with
the SSO profiles.

```#!/bin/bash
./aws-login.sh
```

### 3. Disable a selected security control

To disable an AWS SecurityHub Control using the provided script, follow these steps:

Obtain the Security Control Id associated with the specific control you want to deactivate. You can retrieve it either
from the AWS Security Hub console or through the Command-Line Interface (CLI). To retrieve it using the CLI, run the
following command:

```#!/bin/bash
aws securityhub list-security-control-definitions --standards-arn arn:aws:securityhub:ap-southeast-2::standards/aws-foundational-security-best-practices/v/1.0.0 | \
jq '.SecurityControlDefinitions[].SecurityControlId'
```

Once you have obtained the Security Control Id, execute the deactivation script by running the following command in your
terminal, replacing [SECURITY_CONTROL_ID] with the actual Security Control Id:

```#!/bin/bash
./aws-disable-security-hub-control.sh [SECURITY_CONTROL_ID]
```


If you happen to use this script and feel that it needs improvement, please do so.
