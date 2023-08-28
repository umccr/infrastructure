# AWS Security Hub Control Script

The purpose of this script is to disable AWS Security Hub Controls in all UMCCR accounts that are not relevant to the UMCCR's workloads.

List of accounts that will be disabled:

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

### 3. Disable the relevant controls

To disable the AWS SecurityHub Control with the script just run the `./aws-disable-security-hub-control.sh` followed by
the Control Id.

```#!/bin/bash
./aws-disable-security-hub-control.sh [CONTROL_ID]
```


If you happen to use this script and feel that it needs improvement, please do so.
