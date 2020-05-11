from aws_cdk import (
    aws_codebuild as cb,
    aws_iam as iam,
    aws_s3 as s3,
    aws_stepfunctions as sfn,
    core
)


class SfnStack(core.Stack):

    # #####
    # https://docs.aws.amazon.com/cdk/api/latest/python/aws_cdk.aws_stepfunctions.README.html#state-machine-fragments
    # JSIIError: Cannot read property 'bindToGraph' of undefined

    # class MyJob(sfn.StateMachineFragment):

    #     def __init__(self, parent, id, *, step_name):
    #         super().__init__(parent, id)

    #         first = sfn.Pass(self, step_name+"_First")
    #         second = sfn.Pass(self, step_name+"_Second")
    #         last = sfn.Pass(self, step_name+"_Last")
    #         sfn.Chain.start(first).next(second).next(last)

    #         self.start_state = first
    #         self.end_states = [last]

    #     def start_state(self):
    #         return self.start_state

    #     def end_states(self):
    #         return self.end_states

    def __init__(self, scope: core.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # #####
        # Step Function pipeline

        task_notify_start = sfn.Pass(self, "NofityStart")
        task_code_build = sfn.Pass(self, "CodeBuild")
        task_batch1 = sfn.Pass(self, "BatchValidationRun")
        task_batch2 = sfn.Pass(self, "BatchValidationEval")
        task_summarise_results = sfn.Pass(self, "SummariseResults")
        task_notify_end = sfn.Pass(self, "NotifyEnd")
        task_notify_failure = sfn.Pass(self, "NotifyFailure")


        # fragment = sfn.Parallel(self, "All jobs")
        # fragment.branch(MyJob(self, "Quick", step_name="quick").prefix_states())
        # fragment.branch(MyJob(self, "Medium", step_name="medium").prefix_states())
        # fragment.branch(MyJob(self, "Slow", step_name="slow").prefix_states())


        scatter = sfn.Map(
            self, "Scatter",
            items_path="$.validation_samples",
            parameters={
                "index.$": "$$.Map.Item.Index",
                "item.$": "$$.Map.Item.Value",
                "runId.$": "$.runfolder"},
            result_path="$.mapresults",
            max_concurrency=10
        ).iterator(task_batch1.next(task_batch2))
        scatter.add_catch(task_notify_failure)

        # Now build the workflow graph (chain)
        chain = sfn.Chain.start(task_notify_start)
        chain = chain.next(task_code_build)
        chain = chain.next(scatter)
        chain = chain.next(task_summarise_results)
        chain = chain.next(task_notify_end)

        sfn.StateMachine(
            self,
            "UmccriseCICDSfnStateMachine",
            definition=chain,
        )
