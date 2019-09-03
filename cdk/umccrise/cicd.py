from aws_cdk import (
    aws_codebuild as cb,
    aws_codecommit as cc,
    core
)

class CICDStack(core.Stack):
    def __init__(self, scope: core.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        cb.Project(self, id = "umccrise", 
                    environment = { "buildImage": cb.LinuxBuildImage.from_docker_registry("umccr/umccrise")},
                    source = cb.Source.git_hub(
                        identifier = "umccrise",
                        owner = "umccr",
                        repo = "umccrise",
                        clone_depth = 1,
                        webhook = True
                    )
                  )

app = core.App()
CICDStack(app, "MyCIStack")

app.synth()