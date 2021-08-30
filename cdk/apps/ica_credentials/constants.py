import os

from aws_cdk import core as cdk

CDK_APP_NAME = "ica-credentials"
CDK_APP_PYTHON_VERSION = "3.8"

DEV_ENV = cdk.Environment(
    account=os.environ["CDK_DEFAULT_ACCOUNT"], region=os.environ["CDK_DEFAULT_REGION"]
)

PROD_ENV = cdk.Environment(account="472057503814", region="ap-southeast-2")

ICA_BASE_URL = "https://aps2.platform.illumina.com"
