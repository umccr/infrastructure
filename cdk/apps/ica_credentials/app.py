import os

from aws_cdk import core as cdk

from deployment import IcaCredentialsDeployment

app = cdk.App()

CDK_APP_NAME = "ica-credentials"
CDK_APP_PYTHON_VERSION = "3.8"


ICA_BASE_URL = "https://aps2.platform.illumina.com"


# Development
IcaCredentialsDeployment(
    app,
    f"{CDK_APP_NAME}-dev",
    "dc8e6ba9-b744-437b-b070-4cf014694b3d",
    [
        "0df0356d-3637-48a5-80d1-a924642a6556",
        "dddd6c29-24d3-49f4-91c0-7e818b3c0a21",
    ],
    ICA_BASE_URL,
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
    ["fdd48e11-cdcc-46a9-b5ac-dee3a4c5f19d"],
    ICA_BASE_URL,
    env=cdk.Environment(account="472057503814", region="ap-southeast-2"),
)

app.synth()
