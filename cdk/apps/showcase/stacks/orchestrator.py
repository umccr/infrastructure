from aws_cdk import (
    aws_stepfunctions as sfn,
    aws_stepfunctions_tasks as sfn_tasks,
    core,
)
import echo_tes

class OrchestratorStack(core.Stack):
    def __init__(self, app: core.App, id: str, **kwargs) -> None:
        super().__init__(app, id, **kwargs)

        # XXX: Expose echo_tes from the other class
        sfn_tasks.RunLambdaTask(echo_tes.function, 
                                integration_pattern=sfn.ServiceIntegrationPattern.WAIT_FOR_TASK_TOKEN,
                                payload={"taskCallbackToken": sfn.Context.task_token})