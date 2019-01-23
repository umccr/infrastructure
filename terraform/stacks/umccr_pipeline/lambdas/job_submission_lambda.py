import boto3
import os
import json


DEPLOY_ENV = os.environ.get("DEPLOY_ENV")
SSM_INSTANCE_ID = os.environ.get("SSM_INSTANCE_ID")
WAIT_FOR_ACTIVITY_ARN = os.environ.get("WAIT_FOR_ASYNC_ACTION_ACTIVITY_ARN")
SSM_PARAM_PREFIX = os.environ.get("SSM_PARAM_PREFIX")

ssm_client = boto3.client('ssm')
states_client = boto3.client('stepfunctions')


def getSSMParam(name):
    return ssm_client.get_parameter(
                Name=name,
                WithDecryption=True
           )['Parameter']['Value']


runfolder_base_path = getSSMParam(SSM_PARAM_PREFIX + "runfolder_base_path")             # {{{{ssm:{SSM_PARAM_PREFIX}runfolder_base_path}}}}
bcl2fastq_base_path = getSSMParam(SSM_PARAM_PREFIX + "bcl2fastq_base_path")             # {{{{ssm:{SSM_PARAM_PREFIX}bcl2fastq_base_path}}}}
hpc_dest_base_path = getSSMParam(SSM_PARAM_PREFIX + "hpc_dest_base_path")               # {{{{ssm:{SSM_PARAM_PREFIX}hpc_dest_base_path}}}}
samplesheet_check_script = getSSMParam(SSM_PARAM_PREFIX + "samplesheet_check_script")   # {{{{ssm:{SSM_PARAM_PREFIX}samplesheet_check_script}}}}
bcl2fastq_script = getSSMParam(SSM_PARAM_PREFIX + "bcl2fastq_script")                   # {{{{ssm:{SSM_PARAM_PREFIX}bcl2fastq_script}}}}
checksum_script = getSSMParam(SSM_PARAM_PREFIX + "checksum_script")                     # {{{{ssm:{SSM_PARAM_PREFIX}checksum_script}}}}
hpc_sync_script = getSSMParam(SSM_PARAM_PREFIX + "hpc_sync_script")                     # {{{{ssm:{SSM_PARAM_PREFIX}hpc_sync_script}}}}
s3_sync_script = getSSMParam(SSM_PARAM_PREFIX + "s3_sync_script")                       # {{{{ssm:{SSM_PARAM_PREFIX}s3_sync_script}}}}
hpc_sync_dest_host = getSSMParam(SSM_PARAM_PREFIX + "hpc_sync_dest_host")               # {{{{ssm:{SSM_PARAM_PREFIX}foo}}}}
HPC_SSH_USER = getSSMParam(SSM_PARAM_PREFIX + "hpc_sync_ssh_user")                      # {{{{ssm:{SSM_PARAM_PREFIX}foo}}}}
aws_profile = getSSMParam(SSM_PARAM_PREFIX + "aws_profile")                             # {{{{ssm:{SSM_PARAM_PREFIX}foo}}}}
s3_sync_dest_bucket = getSSMParam(SSM_PARAM_PREFIX + "s3_sync_dest_bucket")             # {{{{ssm:{SSM_PARAM_PREFIX}foo}}}}


def build_command(script_case, input_data, task_token):

    if input_data.get('runfolder'):
        runfolder = input_data['runfolder']
        print(f"runfolder: {runfolder}")
    else:
        raise ValueError('A runfolder parameter is mandatory!')

    runfolder_path = os.path.join(runfolder_base_path, runfolder)  # {{{{ssm:{SSM_PARAM_PREFIX}runfolder_base_path}}}}/{runfolder}
    bcl2fastq_out_path = os.path.join(bcl2fastq_base_path, runfolder)  # {{{{ssm:{SSM_PARAM_PREFIX}bcl2fastq_base_path}}}}/{runfolder}

    # the time (in sec) an script has to execute before it's declared as failed
    execution_timneout = '600'
    command = f"su - limsadmin -c '"
    if script_case == "samplesheet_check":
        samplesheet_path = os.path.join(runfolder_base_path, runfolder, "SampleSheet.csv")
        command += f" conda activate pipeline &&"
        command += f" DEPLOY_ENV={DEPLOY_ENV} AWS_PROFILE={aws_profile}"
        command += f" python {samplesheet_check_script} {samplesheet_path} {runfolder} {task_token}"
        # command += f" python {{{{ssm:{SSM_PARAM_PREFIX}samplesheet_check_script_plain}}}} {samplesheet_path} {runfolder} {task_token}"
    elif script_case == "bcl2fastq":
        execution_timneout = '36000'
        command += f" DEPLOY_ENV={DEPLOY_ENV} AWS_PROFILE={aws_profile}"
        command += f" {bcl2fastq_script} -R {runfolder_path} -n {runfolder} -o {bcl2fastq_out_path} -k {task_token}"
    elif script_case == "create_runfolder_checksums":
        execution_timneout = '36000'
        command += f" DEPLOY_ENV={DEPLOY_ENV} AWS_PROFILE={aws_profile}"
        command += f" {checksum_script} runfolder {runfolder_path} {runfolder} {task_token}"
    elif script_case == "create_fastq_checksums":
        execution_timneout = '36000'
        command += f" DEPLOY_ENV={DEPLOY_ENV} AWS_PROFILE={aws_profile}"
        command += f" {checksum_script} bcl2fastq {bcl2fastq_out_path} {runfolder} {task_token}"
    elif script_case == "sync_runfolder_to_hpc":
        execution_timneout = '10800'
        command += f" DEPLOY_ENV={DEPLOY_ENV} AWS_PROFILE={aws_profile}"
        command += f" {hpc_sync_script} -d {hpc_sync_dest_host} -u {HPC_SSH_USER} -p {hpc_dest_base_path}"
        command += f" -s {runfolder_path} -x Data -x Thumbnail_Images -n {runfolder} -k {task_token}"
    elif script_case == "sync_fastqs_to_hpc":
        execution_timneout = '36000'
        dest_path = os.path.join(hpc_dest_base_path, runfolder)
        command += f" DEPLOY_ENV={DEPLOY_ENV} AWS_PROFILE={aws_profile}"
        command += f" {hpc_sync_script} -d {hpc_sync_dest_host} -u {HPC_SSH_USER} -p {dest_path}"
        command += f" -s {bcl2fastq_out_path} -n {runfolder} -k {task_token}"
    elif script_case == "sync_runfolder_to_s3":
        execution_timneout = '10800'
        command += f" DEPLOY_ENV={DEPLOY_ENV} AWS_PROFILE={aws_profile}"
        command += f" {s3_sync_script} -b {s3_sync_dest_bucket} -n {runfolder} -k {task_token}"
        command += f" -d {runfolder} -s {runfolder_path} -x Data/* -x Thumbnail_Images/*"
    elif script_case == "sync_fastqs_to_s3":
        execution_timneout = '36000'
        command += f" DEPLOY_ENV={DEPLOY_ENV} AWS_PROFILE={aws_profile}"
        command += f" {s3_sync_script} -b {s3_sync_dest_bucket} -n {runfolder} -k {task_token}"
        command += f" -d {runfolder}/{runfolder} -s {bcl2fastq_out_path} -f"
    else:
        print("Unsupported script_case! Should do something sensible here....")
        raise ValueError("No valid execution scritp!")
    command += "'"

    print(f"Script command; {command}")

    return command, execution_timneout


def lambda_handler(event, context):

    print("Received event: " + json.dumps(event, indent=2))

    ############################################################
    # initial checks

    if event.get('script_execution'):
        script_execution = event['script_execution']
        print(f"script_execution: {script_execution}")
    else:
        raise ValueError('A script_execution parameter is mandatory!')

    ############################################################
    # Get the task token from the wait-for activity task

    print("Retrieving task token...")
    print(
        f"...for activity: {WAIT_FOR_ACTIVITY_ARN} and lambda: {context.function_name}")
    activity_task_response = states_client.get_activity_task(
        activityArn=WAIT_FOR_ACTIVITY_ARN,
        workerName=context.function_name, )

    if 'taskToken' in activity_task_response:
        task_token = activity_task_response["taskToken"]
        print(f"Task token: {task_token[:10]}...{task_token[-10:]}")
    else:
        raise ValueError("Activity response did not yield a task token!")

    ############################################################
    # send a command to the SSM for asynchronous execution

    script_command, script_timeout = build_command(script_case=script_execution,
                                                   input_data=event['input'],
                                                   task_token=task_token)

    response = ssm_client.send_command(
        InstanceIds=[SSM_INSTANCE_ID],
        DocumentName="AWS-RunShellScript",
        Parameters={"commands": [script_command], "executionTimeout": [script_timeout]},
        CloudWatchOutputConfig={'CloudWatchOutputEnabled': True}, )

    command_id = response['Command']['CommandId']
    print(f"Command ID: {command_id}")
