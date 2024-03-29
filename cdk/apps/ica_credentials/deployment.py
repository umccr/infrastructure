from typing import Any, List, Optional, Dict

from aws_cdk import core as cdk

from secrets.infrastructure import Secrets


class IcaCredentialsDeployment(cdk.Stage):
    def __init__(
        self,
        scope: cdk.Construct,
        id_: str,
        data_project: Optional[str],
        workflow_projects: Optional[List[str]],
        ica_base_url: str,
        slack_host_ssm_name: str,
        slack_webhook_ssm_name: str,
        github_role_name: Optional[str] = None,
        github_repos: Optional[List] = None,
        **kwargs,
    ):
        """
        Represents the deployment of our stack(s) to a particular environment with a particular set of settings.

        Args:
            scope:
            id_:
            data_project:
            workflow_projects:
            ica_base_url:
            slack_host_ssm_name:
            slack_webhook_ssm_name:
            **kwargs:
        """
        super().__init__(scope, id_, **kwargs)

        stateful = cdk.Stack(self, "stack")

        # this name becomes the prefix of our secrets so we slip in the word ICA to make it
        # obvious when someone sees them that they are associated with ICA
        Secrets(
            stateful,
            "IcaSecrets",
            data_project,
            workflow_projects,
            ica_base_url,
            slack_host_ssm_name,
            slack_webhook_ssm_name,
            github_role_name=github_role_name,
            github_repos=github_repos,
            cdk_env=kwargs.get("env")
        )
