from aws_cdk import (
    core,
    aws_codebuild as cb,
    aws_codepipeline as cp,
    aws_codepipeline_actions as cpa,
    aws_ecr as ecr,
    aws_iam as iam,
    aws_s3 as s3,
)

class CICDStack(core.Stack):
    def __init__(self, app: core.App, id: str, props, **kwargs) -> None:
        super().__init__(app, id, **kwargs)

        # XXX: Refactor into passed props from uppper stack(s)
        # As semver dictates: https://regex101.com/r/Ly7O1x/3/
        semver_tag_regex = '(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'

        # CodeBuild environment and CodePipeline artifact
        source_output = cp.Artifact(artifact_name='source')
        build_env = cb.BuildEnvironment(build_image=cb.LinuxBuildImage.from_docker_registry("docker:dind"),
                                        privileged=True,
                                        compute_type=cb.ComputeType.MEDIUM);

        # Genomic reference data
        refdata = s3.Bucket.from_bucket_attributes(
            self, 'reference_data',
            bucket_name='umccr-refdata-dev'
        )

        # CodeBuild project
        cb_project = cb.Project(self, id = "umccrise",
                    environment = build_env,
                    timeout = core.Duration.hours(3),
                    source = cb.Source.git_hub(
                        identifier = "umccrise",
                        owner = "umccr",
                        repo = "umccrise",
                        clone_depth = 1,
                        webhook = True,
                        webhook_filters=[ cb.FilterGroup.in_event_of(cb.EventAction.PUSH).and_tag_is(semver_tag_regex) ]
                    )
        );
        # XXX: Decompose this into another stack since other CICD stacks do not
        # need to create several ECR repositories, one for UMCCR (org-level) is enough.
        ecr_repo = ecr.Repository(self, id="umccr", repository_name="umccr");
        
        # Tackle IAM permissions
        # https://stackoverflow.com/questions/38587325/aws-ecr-getauthorizationtoken/54806087
        cb_project.role.add_managed_policy(iam.ManagedPolicy.from_aws_managed_policy_name('AmazonEC2ContainerRegistryPowerUser'));
        refdata.grant_read(cb_project);

        # CICD Pipeline itself
        pipeline = cp.Pipeline(
            self, "CICD",
            pipeline_name=f"{props['namespace']}",
            stages=[
                cp.StageProps(
                stage_name='Source',
                actions=[
                        cpa.GitHubSourceAction(
                            action_name = 'github-tag',
                            owner = "umccr",
                            repo = "umccrise",
                            oauth_token = core.SecretValue.secrets_manager("my-github-token"),
                            output = source_output,
                            branch = "develop", # default: 'master'
                            trigger = cpa.GitHubTrigger.POLL
                        ),
                    ]
                ),

                cp.StageProps(
                    stage_name='aws-codebuild',
                    actions=[
                        cpa.CodeBuildAction(
                            action_name = 'CI-docker-build-and-ECR-push',
                            project = cb_project,
                            input = source_output,
                            run_order = 1,
                        )
                    ]
                )
            ]
        );