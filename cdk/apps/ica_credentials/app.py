from aws_cdk import core as cdk

import constants
from deployment import IcaCredentialsDeployment

app = cdk.App()

# Development
IcaCredentialsDeployment(
    app,
    f"{constants.CDK_APP_NAME}-Dev",
    env=constants.DEV_ENV,
)

# Production
IcaCredentialsDeployment(
    app,
    f"{constants.CDK_APP_NAME}-Prod",
    env=constants.PROD_ENV,
)

app.synth()
