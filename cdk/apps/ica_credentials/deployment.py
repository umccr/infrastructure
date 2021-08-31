from typing import Any, List

from aws_cdk import core as cdk

from secrets.infrastructure import Secrets


class IcaCredentialsDeployment(cdk.Stage):
    def __init__(
        self,
        scope: cdk.Construct,
        id_: str,
        data_project: str,
        workflow_projects: List[str],
        ica_base_url: str,
        **kwargs: Any,
    ):
        super().__init__(scope, id_, **kwargs)

        stateful = cdk.Stack(self, "stack")

        # this name becomes the prefix of our secrets so we slip in the ICA to make it
        # obvious when someone sees them that they are associated with ICA
        Secrets(stateful, "IcaSecrets", data_project, workflow_projects, ica_base_url)
