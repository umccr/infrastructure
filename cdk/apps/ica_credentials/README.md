# ICA Credentials

A stack for managing ICA credentials and the production of up-to-date JWTs (as AWS secrets).

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
- manually change each secret rotation to Disabled
- go to the Cloud Formation and 'continue rollback'
- manually change each secret again to Disabled (the rollback will have re-enabled them)
- then apply the CDK changes


## Dev

A development system requires a working Python and Node.

`make` should be all that is required to do a setup and type check of the source code.

To actually deploy to dev, use

`make deploy-cdk-dev`

whilst in a shell with AWS access keys for dev. The deployed stack in dev will
perform rotations but only message to Slack infrequently. There are various
settings in the code if you want to test more frequent Slack messaging.

If you want to change the Python requirements, just edit the relevant `requirements.in`
file and then do a `make`. It will re-compile the actual `requirements.txt` (and maybe
also possibly update package versions). 

NOTE: currently the lambdas do *not* require any Python libraries
(other than AWS and urllib which are built in) so are
built very simply by the CDK (they do not have their own `requirements.txt`). This
might need to change - at which point the CDK build will need to be more
sophisticated.

