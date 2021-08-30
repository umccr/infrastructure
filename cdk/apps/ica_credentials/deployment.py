from typing import Any

from aws_cdk import core as cdk

from secrets.infrastructure import Secrets


class IcaCredentialsDeployment(cdk.Stage):
    def __init__(
        self,
        scope: cdk.Construct,
        id_: str,
        **kwargs: Any,
    ):
        super().__init__(scope, id_, **kwargs)

        stateful = cdk.Stack(self, "IcaCredentials")

        # this name becomes the prefix of our secrets so we slip in the ICA to make it
        # obvious when someone seems them
        s = Secrets(stateful, "IcaSecrets")
