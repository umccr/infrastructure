# ICA Credentials

A stack for managing ICA credentials and the production of up to date JWTs.

## Setup

After installing with CDK, the master API secret must be set to a value by the account
administrator, using a API key produced in ICA by the service user.
(note the use of single quotes to switch off shell substitution - the passwords can
contain bash special characters).

e.g.

```bash
aws secretsmanager put-secret-value \
  --secret-id '<insert master secret name>' \
  --secret-string '<insert API key>'
```

This cannot be done in the AWS Console UI as the administrator user is not allowed to read the
value - hence they can only set the value via CLI.

## Use

### Portal

From any account with access to the secret `IcaSecretsPortal` - retrieve the value. The
content of the SecureString will be the JWT.

### Workflows

```bash
aws secretsmanager get-secret-value --secret-id IcaSecretsWorkflow --query 'SecretString' --output text | jq
```

will show a JSON object, keyed by ICA project id - and with an up to date JWT for
that project.

## Ops

*If* you are making a change to any setting of the secret rotations (duration, lambda etc) - doing a
CDK deploy mid-rotation can be catastrophic (in can leave it not just rolled back - but Failed Rolled Back).
*In particular*, if the rotations are not completing due to any errors in the lambda then they
are by definition always mid-rotation and hence can't be updated.

The trick is:
- manually change each secret to Disabled
- then apply the CDK changes

If your CDK stack gets stuck in "Failed Rollback":
- manually change each secret to Disabled
- go to the Cloud Formation and 'continue rollback'
- manually change each secret again to Disabled (the rollback will have re-enabled them)
- then apply the CDK changes


## Dev

### Create Python virtual environment and install the dependencies

```bash
python3.8 -m venv .venv
source .venv/bin/activate
# [Optional] Needed to upgrade dependencies and cleanup unused packages
pip install pip-tools==6.1.0
./scripts/install-deps.sh
```

