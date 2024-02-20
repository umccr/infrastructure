# aws_bootstrap

See story https://trello.com/c/jn56wL6f


## TL;DR

* I want to update (make changes to) the [CDK bootstrap](https://docs.aws.amazon.com/cdk/v2/guide/bootstrapping.html) stack (i.e. `CDKToolkit`) in the specified AWS account, how?
  * Make a PR to update/change request to the [bootstrap-template.yaml](bootstrap-template.yaml).
  * Add PR review to Flo/Victor then to follow up with the steps below in AWS Console there.


## Steps

1. Prepare your AWS CLI config to align as prescribed in [all-accounts-aws-config.ini](../all-accounts-aws-config.ini).
2. Login to have fresh SSO session:
   ```
   aws sso login --sso-session umccr
   aws sso login --sso-session unimelb
   ```
3. Read to understand the notes in the script [bootstrap-update-all.sh](bootstrap-update-all.sh).
4. Execute like so: `zsh bootstrap-update-all.sh`.
5. Login to `AWS Console > CloudFormation > CDKToolkit > Change sets (tab) > Execute change set` to complete the process.
6. If there is no changes to apply in the changeset, just simply delete your changeset that has created by the script execution.


## Expect

An example execution as follows:

```
zsh bootstrap-update-all.sh

----------------------------
Deploying CDK for account unimelb-toolchain-admin

Waiting for changeset to be created..
Changeset created successfully. Run the following command to review changes:
aws cloudformation describe-change-set --change-set-name arn:aws:cloudformation:ap-southeast-2:1234567890:changeSet/awscli-cloudformation-package-deploy-1111333545/5762849b-5691-530f-bf44-605a24125fd3

----------------------------
Deploying CDK for account unimelb-demo-admin

Waiting for changeset to be created..
Changeset created successfully. Run the following command to review changes:
aws cloudformation describe-change-set --change-set-name arn:aws:cloudformation:ap-southeast-2:<..snap..>

----------------------------
Deploying CDK for account unimelb-australiangenomics-admin

Waiting for changeset to be created..
Changeset created successfully. Run the following command to review changes:
aws cloudformation describe-change-set --change-set-name arn:aws:cloudformation:ap-southeast-2:<..snap..>

----------------------------
Deploying CDK for account unimelb-beta-admin

Waiting for changeset to be created..
Changeset created successfully. Run the following command to review changes:
aws cloudformation describe-change-set --change-set-name arn:aws:cloudformation:ap-southeast-2:<..snap..>

----------------------------
Deploying CDK for account unimelb-gamma-admin

Waiting for changeset to be created..
Changeset created successfully. Run the following command to review changes:
aws cloudformation describe-change-set --change-set-name arn:aws:cloudformation:ap-southeast-2:<..snap..>
```
