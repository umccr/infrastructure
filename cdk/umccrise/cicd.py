from aws_cdk import (
    core,
    aws_codebuild as cb,
    aws_codecommit as cc,
    aws_codepipeline as cp
)

class CICDStack(core.Stack):
    def __init__(self, scope: core.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        cb.Project(self, id = "umccrise",
                    environment = { "buildImage": cb.LinuxBuildImage.STANDARD_2_0, "privileged": True},
                    source = cb.Source.git_hub(
                        identifier = "umccrise",
                        owner = "umccr",
                        repo = "umccrise",
                        clone_depth = 1,
                        webhook = True,
                    )
                  )

app = core.App()
CICDStack(app, "UmccriseCICDStack")

# XXX: https://stackoverflow.com/questions/38587325/aws-ecr-getauthorizationtoken/54806087
# Because of GitHub MFA, we are getting "is not authorized to perform: ecr:GetAuthorizationToken on resource: *"
# Assigning Policy to CICD role "AmazonEC2ContainerRegistryPowerUser" for now...

app.synth()
