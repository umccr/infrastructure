#!/bin/python
import sys
sys.path.insert(0, '../lambdas')
import job_submission_lambda  # noqa

help_text = """
This script allows you to call individual pipeline steps in an analogous way the AWS pipeline
would do. It will use the same execution mechanism and run commands are issued and logged in AWS.
NOTE: Use as emergency option only!
      The AWS infraxtructure is set up to work with a Step Functions pipeline. However, as there
      is no pipeline with this approach, associated rules and events won't find the expected targets
      and therefore fail. As a consequence no Slack notifications will be issued either and command
      success has to be monitored manually.

Make sure AWS credetials and the required ENV variables are in place.
Examples for the dev account:
    export SSM_DOC_NAME="UMCCR-RunShellScriptFromStepFunction"
    export DEPLOY_ENV="dev"
    export WAIT_FOR_ASYNC_ACTION_ACTIVITY_ARN="not_used_but_needed"
    export SSM_PARAM_PREFIX="/umccr_pipeline/novastor/"
    export BASTION_SSM_ROLE_ARN="arn:aws:iam::383856791668:role/umccr_pipeline_bastion_ssm_role"

Choose pipeline step to run:
    runfolder_check
    samplesheet_check
    bcl2fastq
    create_runfolder_checksums
    create_fastq_checksums
    sync_runfolder_to_hpc
    sync_fastqs_to_hpc
    sync_runfolder_to_s3
    sync_fastqs_to_s3
    google_lims_update
    stats_sheet_update

and the runfolder to run it on. Example:
    181220_A00130_0088_AHFTTLDSXX

Then execute:
    python execute_pipeline_step_manually.py <pipeline step> <runfolder>
"""


if len(sys.argv) != 3:
    print("Invalid execution!")
    print(help_text)
    exit(1)

execution_step = sys.argv[1]
runfolder = sys.argv[2]

print(execution_step + " for " + runfolder)

event = {'script_execution': execution_step, 'input': {'runfolder': runfolder}}

job_submission_lambda.manual_handling(event)
