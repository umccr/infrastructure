from typing import List, Optional, Any

from constructs import Construct
from aws_cdk import App, Stack, Stage

from secrets.infrastructure import Secrets


class IcaCredentialsDeployment(Stage):
    def __init__(
        self,
        scope: Construct,
        id_: str,
        data_project: Optional[str],
        workflow_projects: Optional[List[str]],
        ica_base_url: str,
        slack_host_ssm_name: str,
        slack_webhook_ssm_name: str,
        github_role_name: Optional[str] = None,
        github_repos: Optional[List[str]] = None,
        **kwargs: Any,
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

        stateful = Stack(self, "stack")

        # this name becomes the prefix of our secrets so we slip in the word ICA to make it
        # obvious when someone sees them that they are associated with ICA
        Secrets(
            stateful,
            "IcaSecrets",
            data_project,
            workflow_projects,
            ica_base_url,
            "cron(0 4/12 * * ? *)",
            slack_host_ssm_name,
            slack_webhook_ssm_name,
            github_role_name=github_role_name,
            github_repos=github_repos,
        )
