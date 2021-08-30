# ICA Credentials

A stack for managing ICA credentials.

## Setup

After installing with CDK, the master API secret must be set to a value.

e.g.

```
aws secretsmanager put-secret-value \
  --secret-id "<insert master secret name>" \
  --secret-string "<insert API key>"
```

This cannot be done in the AWS Console UI as the administrator user is not allowed to read the
value - hence they can't set the value.


## Instructions from boilerplate project

## Create development environment

### Create Python virtual environment and install the dependencies
```bash
python3.8 -m venv .venv
source .venv/bin/activate
# [Optional] Needed to upgrade dependencies and cleanup unused packages
pip install pip-tools==6.1.0
./scripts/install-deps.sh
./scripts/run-tests.sh
```

### [Optional] Upgrade AWS CDK Toolkit version
**Note:** If you are planning to upgrade dependencies, first push the upgraded AWS CDK Toolkit version.
See [(pipelines): Fail synth if pinned CDK CLI version is older than CDK library version](https://github.com/aws/aws-cdk/issues/15519) 
for more details.

```bash
vi package.json  # Update "aws-cdk" package version
./scripts/install-deps.sh
./scripts/run-tests.sh
```

### [Optional] Upgrade dependencies (ordered by constraints)
Consider [AWS CDK Toolkit (CLI)](https://docs.aws.amazon.com/cdk/latest/guide/reference.html#versioning) compatibility 
when upgrading AWS CDK packages version.

```bash
pip-compile --upgrade api/runtime/requirements.in
pip-compile --upgrade requirements.in
pip-compile --upgrade requirements-dev.in
./scripts/install-deps.sh
# [Optional] Cleanup unused packages
pip-sync api/runtime/requirements.txt requirements.txt requirements-dev.txt
./scripts/run-tests.sh
```
