from aws_cdk import (
    core,
    aws_codebuild as cb,
    aws_codepipeline as cp,
    aws_codepipeline_actions as cpa,
    aws_ecr as ecr,
    aws_iam as iam,
    aws_s3 as s3,
)

# As semver dictates: https://regex101.com/r/Ly7O1x/3/
semver_tag_regex = '(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'


class CommonStack(core.Stack):
    def __init__(self, scope: core.Construct, id: str, props, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # create an ECR repo to deploy the created image to (defined in build spec)
        ecr.Repository(
            self,
            id="UmccriseEcrRepo",
            repository_name=props['umccrise_ecr_repo'])


class CICDStack(core.Stack):
    def __init__(self, scope: core.Construct, id: str, props, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        refdata = s3.Bucket.from_bucket_attributes(
            self,
            'reference_data',
            bucket_name='umccr-refdata-dev'
        )

        build_env = cb.BuildEnvironment(build_image=cb.LinuxBuildImage.from_docker_registry("docker:dind"),
                                        privileged=True,
                                        compute_type=cb.ComputeType.MEDIUM)

        # create an ECR repo to deploy the created image to (defined in build spec)
        ecr.Repository(self, id="umccr", repository_name="umccr")

        cb_project = cb.Project(
            self,
            id="umccrise",
            environment=build_env,
            timeout=core.Duration.hours(3),
            source=cb.Source.git_hub(
                identifier="umccrise",
                owner="umccr",
                repo="umccrise",
                clone_depth=1,
                webhook=True,
                webhook_filters=[
                    cb.FilterGroup.in_event_of(cb.EventAction.PUSH).and_tag_is(semver_tag_regex)
                ]
            )
        )

        # Tackle IAM permissions
        # https://stackoverflow.com/questions/38587325/aws-ecr-getauthorizationtoken/54806087
        cb_project.role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name('AmazonEC2ContainerRegistryPowerUser')
        )
        refdata.grant_read(cb_project)


class CICDPipelineStack(core.Stack):
    def __init__(self, app: core.App, id: str, props, **kwargs) -> None:
        super().__init__(app, id, **kwargs)

        # Reference data bucket
        refdata = s3.Bucket.from_bucket_attributes(
            self,
            'ReferenceDataBucket',
            bucket_name=props['refdata_bucket']
        )

        # TODO: setup secret in SM
        github_token = core.SecretValue.secrets_manager(
            '/umccrise/pipeline/github/token',
            json_field='github-token',
        )

        # ECR repo to hold umccrise images (see buildspec.yaml)
        ecr_repo = ecr.Repository.from_repository_name(
            self,
            id='EcrRepo',
            repository_name=props['ecr_repo'],
        )

        # S3 bucket for CDK artifacts
        artifact_bucket = s3.Bucket(
            self,
            'UmccriseCdkBucket',
            bucket_name=f"umccr-{props['namespace']}"
        )

        # CodeBuild environment and CodePipeline artifact
        build_env = cb.BuildEnvironment(
            build_image=cb.LinuxBuildImage.from_docker_registry("docker:dind"),
            privileged=True,
            compute_type=cb.ComputeType.MEDIUM
        )

        # CodeBuild project
        build_project = cb.PipelineProject(
            self, 'BuildProject',
            project_name=f"{props['namespace']}-build-project",
            description='Build project for the umccrise build pipeline',
            environment=build_env,
            cache=cb.Cache.bucket(artifact_bucket, prefix='codebuild-cache'),
        )
        ecr_repo.grant_pull_push(build_project)
        refdata.grant_read(build_project)
        artifact_bucket.grant_read_write(build_project)

        # Pipeline input/outputs
        source_output = cp.Artifact(artifact_name='source-output')
        build_output = cp.Artifact(artifact_name='build-output')

        # Pipeline actions
        github_source_action = cpa.GitHubSourceAction(
            action_name='SourceCodeRepo',
            owner=props['github_repo_owner'],
            repo=props['github_repo'],
            oauth_token=github_token,
            output=source_output,
            branch=props['github_branch'],
            trigger=cpa.GitHubTrigger.WEBHOOK  # default
        )

        code_build_action = cpa.CodeBuildAction(
            action_name='CodeBuildProject',
            input=source_output,
            outputs=[build_output],
            project=build_project,
            type=cpa.CodeBuildActionType.BUILD,
        )

        # Pipeline definition
        umccrise_pipeline = cp.Pipeline(
            self,
            'UmccrisePipeline',
            pipeline_name=f"{props['namespace']}-pipeline",
            artifact_bucket=artifact_bucket,
            restart_execution_on_update=True
        )
        artifact_bucket.grant_read_write(umccrise_pipeline.role)

        umccrise_pipeline.add_stage(
            stage_name='Source',
            actions=[github_source_action]
        )

        umccrise_pipeline.add_stage(
            stage_name='Build',
            actions=[code_build_action]
        )
