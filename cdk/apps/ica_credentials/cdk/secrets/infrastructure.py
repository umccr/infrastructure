import os
from typing import List, Tuple, Union, Optional

from constructs import Construct
from aws_cdk import App, Environment, Duration

from aws_cdk import (
    aws_lambda as lambda_,
    aws_secretsmanager as secretsmanager,
    aws_events as events,
    aws_events_targets as events_targets,
    aws_iam as iam,
)
import logging

ROTATION_DAYS = 1


class Secrets(Construct):
    """
    A construct that maintains secrets for ICA and periodically generates fresh JWT secrets.
    """

    def __init__(
            self,
            scope: Construct,
            id_: str,
            data_project: Optional[str],
            workflow_projects: Optional[List[str]],
            ica_base_url: str,
            slack_host_ssm_name: str,
            slack_webhook_ssm_name: str,
            github_repos: Optional[List[str]],
            github_role_name: str,
            cdk_env: Environment
    ):
        super().__init__(scope, id_)

        master = self.create_master_secret()

        jwt_portal_secret, jwt_portal_func = self.create_jwt_secret(
            master, ica_base_url, id_ + "Portal", data_project
        )
        jwt_workflow_secret, jwt_workflow_func = self.create_jwt_secret(
            master, ica_base_url, id_ + "Workflow", workflow_projects
        )

        # set the policy for the master secret to deny everyone except the rotators access
        self.add_deny_for_everyone_except(master, [jwt_portal_func, jwt_workflow_func])

        # log rotation events to slack
        self.create_event_handling(
            [jwt_portal_secret, jwt_workflow_secret],
            slack_host_ssm_name,
            slack_webhook_ssm_name,
        )

        # share the JWT secrets with the GitHub Actions repo
        self.share_jwt_secret_with_github_actions_repo(
            jwt_workflow_secret,
            github_repos,
            github_role_name,
            cdk_env.account
        )

    def create_master_secret(self) -> secretsmanager.Secret:
        """
        Create the master API key secret - for holding the API key of the master service user.
        This key is only then used by the key rotation lambdas of other secrets.

        Returns:
            the master secret
        """

        # we start the secret with a random value created by secrets manager..
        # first step will be to set this to an API key from Illumina ICA
        master_secret = secretsmanager.Secret(
            self,
            "MasterApiKeySecret",
            description="Master ICA API key - not for direct use - use corresponding JWT secrets",
        )

        return master_secret

    def add_deny_for_everyone_except(
            self,
            master_secret: secretsmanager.Secret,
            producer_functions: List[lambda_.Function],
    ) -> None:
        """
        Sets up the master secret resource policy so that everything *except* the given functions
        is denied access to GetSecretValue.

        Args:
            master_secret: the master secret construct
            producer_functions: a list of functions we are going to set as the only allowed accessors
        """
        # this end locks down the master secret so that *only* the JWT producer can read values
        # (it is only when we set the DENY policy here that in general other roles in the same account
        #  cannot access the secret value - so it is only after doing that that we need to explicitly enable
        #  the role we do want to access it)
        role_arns: List[str] = []

        for f in producer_functions:
            if not f.role:
                raise Exception(
                    f"Rotation function {f.function_name} has somehow not created a Lambda role correctly"
                )

            role_arns.append(f.role.role_arn)

        master_secret.add_to_resource_policy(
            iam.PolicyStatement(
                effect=iam.Effect.DENY,
                actions=["secretsmanager:GetSecretValue"],
                resources=["*"],
                principals=[iam.AccountRootPrincipal()],
                # https://stackoverflow.com/questions/63915906/aws-secrets-manager-resource-policy-to-deny-all-roles-except-one-role
                conditions={
                    "ForAllValues:StringNotEquals": {"aws:PrincipalArn": role_arns}
                },
            )
        )

    def create_jwt_secret(
            self,
            master_secret: secretsmanager.Secret,
            ica_base_url: str,
            key_name: str,
            project_ids: Optional[Union[str, List[str]]],
    ) -> Tuple[secretsmanager.Secret, lambda_.Function]:
        """
        Create a JWT holding secret - that will use the master secret for JWT making - and which will have
        broad permissions to be read by all roles.

        Args:
            master_secret: the master secret to read for the API key for JWT making
            ica_base_url: the base url of ICA to be passed on to the rotators
            key_name: a unique string that we use to name this JWT secret
            project_ids: *either* a single string or a list of string - the choice of type *will* affect
                         the resulting secret output i.e a string input will end up different to a list with one string!

        Returns:
            the JWT secret
        """
        dirname = os.path.dirname(__file__)
        filename = os.path.join(dirname, "../../lambdas/jwt_producer_lambda")

        env = {
            "MASTER_ARN": master_secret.secret_arn,
            "ICA_BASE_URL": ica_base_url,
        }

        # flip the instructions to our single lambda - the handle either a single JWT generator or
        # dictionary of JWTS
        if ica_base_url == "https://ica.illumina.com":  # V2
            env["ICA_PLATFORM_VERSION"] = "V2"
        else:  # V1
            env["ICA_PLATFORM_VERSION"] = "V1"
            if isinstance(project_ids, List):
                env["PROJECT_IDS"] = " ".join(project_ids)
            else:
                env["PROJECT_ID"] = project_ids

        jwt_producer = lambda_.Function(
            self,
            "JwtProduce" + key_name,
            runtime=lambda_.Runtime.PYTHON_3_11,    # type: ignore
            code=lambda_.AssetCode(filename),
            handler="lambda_entrypoint.main",
            timeout=Duration.minutes(1),
            environment=env,
        )

        # this end makes the lambda role for JWT producer able to attempt to read the master secret
        # (this is only one part of the permission decision though - also need to set the Secrets policy too)
        master_secret.grant_read(jwt_producer)

        # secret itself - no default value as it will eventually get replaced by the JWT
        jwt_secret = secretsmanager.Secret(
            self,
            "Jwt" + key_name,
            secret_name=key_name,
            description="JWT(s) providing access to ICA projects",
        )

        # the rotation function that creates JWTs
        jwt_secret.add_rotation_schedule(
            "JwtSecretRotation",
            automatically_after=Duration.days(ROTATION_DAYS),
            rotation_lambda=jwt_producer,
        )

        return jwt_secret, jwt_producer

    def create_event_handling(
            self,
            secrets: List[secretsmanager.Secret],
            slack_host_ssm_name: str,
            slack_webhook_ssm_name: str,
    ) -> lambda_.Function:
        """

        Args:
            secrets: a list of secrets that we will track for events
            slack_host_ssm_name: the SSM parameter name for the slack host
            slack_webhook_ssm_name: the SSM parameter name for the slack webhook id

        Returns:
            a lambda event handler
        """
        dirname = os.path.dirname(__file__)
        filename = os.path.join(dirname, "../../lambdas/notify_slack_lambda")

        env = {
            # for the moment we don't parametrise at the CDK level.. only needed if this is liable to change
            "SLACK_HOST_SSM_NAME": slack_host_ssm_name,
            "SLACK_WEBHOOK_SSM_NAME": slack_webhook_ssm_name,
        }

        notifier = lambda_.Function(
            self,
            "NotifySlack",
            runtime=lambda_.Runtime.PYTHON_3_11,    # type: ignore
            code=lambda_.AssetCode(filename),
            handler="lambda_entrypoint.main",
            timeout=Duration.minutes(1),
            environment=env,
        )

        get_ssm_policy = iam.PolicyStatement()

        # there is some weirdness around SSM parameter ARN formation and leading slashes.. can't be bothered
        # looking into right now - as the ones we want to use do a have a leading slash
        # but put in this exception in case
        if not slack_webhook_ssm_name.startswith("/") or not slack_host_ssm_name.startswith("/"):
            raise Exception("SSM parameters need to start with a leading slash")

        # see here - the *required* slash between parameter and the actual name uses the leading slash from the actual
        # name itself.. which is wrong..
        get_ssm_policy.add_resources(f"arn:aws:ssm:*:*:parameter{slack_host_ssm_name}")
        get_ssm_policy.add_resources(f"arn:aws:ssm:*:*:parameter{slack_webhook_ssm_name}")
        get_ssm_policy.add_actions("ssm:GetParameter")

        notifier.add_to_role_policy(get_ssm_policy)

        # we want a rule that traps all the rotation failures for our JWT secrets
        rule = events.Rule(
            self,
            "NotifySlackRule",
        )

        rule.add_event_pattern(
            source=["aws.secretsmanager"],
            detail={
                # at the moment only interested in these - add extra events into this array if wanting more
                "eventName": ["RotationFailed", "RotationSucceeded"],
                "additionalEventData": {
                    "SecretId": list(map(lambda s: s.secret_arn, secrets))
                },
            },
        )

        rule.add_target(events_targets.LambdaFunction(notifier))

        return notifier

    def share_jwt_secret_with_github_actions_repo(
            self,
            secret: secretsmanager.Secret,
            github_repositories: Optional[List[str]],
            role_name: Optional[str],
            account_id: Optional[str]
    ):
        """
        Given a list of GitHub repositories, allow this secret to be accessed by the repo
        :param secret: The secretsmanager object that will shared the role will have access to the value of
        :param github_repositories: A list of GitHub repositories that will be given access to the secret
        :param role_name: The name of the role that will be created and given access to the secret
        :param account_id: The AWS account ID of the account that the role will be created in
        :return:
        """
        # Check inputs
        if github_repositories is None or len(github_repositories) == 0:
            logging.info("No GitHub repositories to add this role to")
            return

        if role_name is None:
            logging.info("Role name not specified - not adding to GitHub repositories")
            return

        # Set role
        gh_action_role = iam.Role(
            self,
            role_name,
            assumed_by=iam.FederatedPrincipal(
                f"arn:aws:iam::{account_id}:oidc-provider/token.actions.githubusercontent.com",
                {
                    "StringEquals": {
                        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                    },
                    "StringLike": {
                        "token.actions.githubusercontent.com:sub": github_repositories
                    }
                },
                "sts:AssumeRoleWithWebIdentity"
            )
        )

        # Add permissions to role
        gh_action_role.add_to_policy(
            iam.PolicyStatement(
                actions=[
                    "secretsmanager:GetSecretValue",
                ],
                resources=[
                    secret.secret_arn
                ]
            )
        )
