import os

from aws_cdk import core as cdk

from deployment import IcaCredentialsDeployment

app = cdk.App()

CDK_APP_NAME = "ica-credentials"
CDK_APP_PYTHON_VERSION = "3.8"

ICA_BASE_URL = "https://aps2.platform.illumina.com"
ICAV2_BASE_URL = "https://ica.illumina.com"

SLACK_HOST_SSM_NAME = "/slack/webhook/host"
SLACK_WEBHOOK_SSM_NAME = "/slack/webhook/id"


# Development
IcaCredentialsDeployment(
    app,
    f"{CDK_APP_NAME}-dev",
    "dc8e6ba9-b744-437b-b070-4cf014694b3d",
    [
        # development_workflows
        "0df0356d-3637-48a5-80d1-a924642a6556",
        # collab-illumina-dev_workflows
        "dddd6c29-24d3-49f4-91c0-7e818b3c0a21",
    ],
    ICA_BASE_URL,
    SLACK_HOST_SSM_NAME,
    SLACK_WEBHOOK_SSM_NAME,
    env=cdk.Environment(
        account=os.environ["CDK_DEFAULT_ACCOUNT"],
        region=os.environ["CDK_DEFAULT_REGION"],
    ),
)

# Production
IcaCredentialsDeployment(
    app,
    f"{CDK_APP_NAME}-prod",
    "20b42a71-1ebc-4e7b-b659-313f2f4524c3",
    [
        # production_workflows
        "fdd48e11-cdcc-46a9-b5ac-dee3a4c5f19d"
    ],
    ICA_BASE_URL,
    SLACK_HOST_SSM_NAME,
    SLACK_WEBHOOK_SSM_NAME,
    env=cdk.Environment(
        account="472057503814",
        region="ap-southeast-2"
    ),
)

# V2 (single token)
IcaCredentialsDeployment(
    app,
    f"{CDK_APP_NAME}-dev-v2",
    None,  # Token does not require project context in v2
    None,  # Token does not require additional project list in v2
    ICAV2_BASE_URL,
    SLACK_HOST_SSM_NAME,
    SLACK_WEBHOOK_SSM_NAME,
    env=cdk.Environment(
        account=os.environ["CDK_DEFAULT_ACCOUNT"],
        region=os.environ["CDK_DEFAULT_REGION"],
    ),
)

app.synth()
