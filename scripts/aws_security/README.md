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

To deactivate the AWS SecurityHub Control using the script, execute the command `./aws-disable-security-hub-control.sh`
and provide the corresponding Security Control Id as an argument. The Security Control Id can be obtained either from the AWS
Security Hub console or through the CLI using the command `aws securityhub list-security-control-definitions`.

```#!/bin/bash
./aws-disable-security-hub-control.sh [SECURITY_CONTROL_ID]
```


If you happen to use this script and feel that it needs improvement, please do so.
