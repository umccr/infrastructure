from aws_cdk import (
    Stack,
    Duration,
    aws_codebuild as codebuild,
    aws_iam as iam
)

from constructs import Construct

from pathlib import Path
from typing import Dict

# As semver dictates: https://regex101.com/r/Ly7O1x/3/
semver_tag_regex = '(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'

"""
Much of this work is from this stackoverflow answer: https://stackoverflow.com/a/67864008/6946787 
"""


class CttsoIcaToPieriandxDockerBuildStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, props: Dict, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Defining app stage

        # Get the build environment
        build_env = codebuild.BuildEnvironment(
            build_image=codebuild.LinuxBuildImage.STANDARD_4_0,
            privileged=True, # pass the ecr repo uri into the codebuild project so codebuild knows where to push
            environment_variables={
                'CONTAINER_REPO': codebuild.BuildEnvironmentVariable(value=props.get("container_repo")),
                'CONTAINER_NAME': codebuild.BuildEnvironmentVariable(value=props.get("container_name")),
                'REGION': codebuild.BuildEnvironmentVariable(value=props.get("region")),
            }
        )

        # Deploy
        code_build_project = codebuild.Project(
            self,
            id="cttsoicatopieriandxCodeBuildProject",
            project_name=props['codebuild_project_name'],
            environment=build_env,
            timeout=Duration.hours(3),
            source=codebuild.Source.git_hub(
                identifier="cttsoicatopieriandx",
                owner="umccr",
                repo="cttso-ica-to-pieriandx",
                clone_depth=1,
                webhook=True,
                webhook_filters=[
                    codebuild.FilterGroup.in_event_of(codebuild.EventAction.PUSH).and_tag_is(semver_tag_regex)
                ]
            )
        )

        # Tackle IAM permissions
        # https://stackoverflow.com/questions/38587325/aws-ecr-getauthorizationtoken/54806087
        code_build_project.role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name('AmazonEC2ContainerRegistryPowerUser')
        )
        # For adding container to ssm
        code_build_project.role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("AmazonSSMFullAccess")
        )