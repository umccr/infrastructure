# ICA Credentials

A stack for managing ICA credentials and the production of up to date JWTs.

## Setup

After installing with CDK, the master API secret must be set to a value by the account
administrator, using a API key produced in ICA by the service user.

e.g.

```bash
aws secretsmanager put-secret-value \
  --secret-id "<insert master secret name>" \
  --secret-string "<insert API key>"
```

This cannot be done in the AWS Console UI as the administrator user is not allowed to read the
value - hence they can't set the value.

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


## Dev

### Create Python virtual environment and install the dependencies

```bash
python3.8 -m venv .venv
source .venv/bin/activate
# [Optional] Needed to upgrade dependencies and cleanup unused packages
pip install pip-tools==6.1.0
./scripts/install-deps.sh
```

