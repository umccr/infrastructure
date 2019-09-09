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

app.synth()