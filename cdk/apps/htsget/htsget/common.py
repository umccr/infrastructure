from aws_cdk import (
    core,
    aws_ecr as ecr
)


class CommonStack(core.Stack):
    def __init__(self, scope: core.Construct, id_: str, props, **kwargs) -> None:
        super().__init__(scope, id_, **kwargs)

        namespace = props['namespace']

        ecr_repo = ecr.Repository(
            self,
            id="HtsgetRefServerEcrRepo",
            repository_name=namespace,
            removal_policy=core.RemovalPolicy.RETAIN
        )
        self._ecr_repo = ecr_repo

    @property
    def ecr_repo(self):
        return self._ecr_repo
