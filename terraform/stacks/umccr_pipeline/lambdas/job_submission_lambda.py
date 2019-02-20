import boto3
import os
import json

SSM_DOC_NAME = os.environ.get("SSM_DOC_NAME")
DEPLOY_ENV = os.environ.get("DEPLOY_ENV")
WAIT_FOR_ACTIVITY_ARN = os.environ.get("WAIT_FOR_ASYNC_ACTION_ACTIVITY_ARN")
SSM_PARAM_PREFIX = os.environ.get("SSM_PARAM_PREFIX")
BASTION_SSM_ROLE_ARN = os.environ.get("BASTION_SSM_ROLE_ARN")

ssm_client = boto3.client('ssm')
states_client = boto3.client('stepfunctions')


def getSSMParam(name):
    """
    Fetch the parameter with the given name from SSM Parameter Store.
    """
    return ssm_client.get_parameter(
                Name=name,
                WithDecryption=True
           )['Parameter']['Value']


# We could use the in-command notation for Parameter Store parameters as explained here:
# https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-about.html
#   Example of in-command parameter usage:
#   command += f" python {{{{ssm:{SSM_PARAM_PREFIX}samplesheet_check_script_plain}}}} {samplesheet_path} ..."
# However, that does not suppport encrypted parameters!
# Therefore we have to fetch the parameters ourselves
ssm_instance_id = getSSMParam(SSM_PARAM_PREFIX + "ssm_instance_id")
runfolder_base_path = getSSMParam(SSM_PARAM_PREFIX + "runfolder_base_path")
bcl2fastq_base_path = getSSMParam(SSM_PARAM_PREFIX + "bcl2fastq_base_path")
hpc_dest_base_path = getSSMParam(SSM_PARAM_PREFIX + "hpc_dest_base_path")
runfolder_check_script = getSSMParam(SSM_PARAM_PREFIX + "runfolder_check_script")
samplesheet_check_script = getSSMParam(SSM_PARAM_PREFIX + "samplesheet_check_script")
bcl2fastq_script = getSSMParam(SSM_PARAM_PREFIX + "bcl2fastq_script")
checksum_script = getSSMParam(SSM_PARAM_PREFIX + "checksum_script")
hpc_sync_script = getSSMParam(SSM_PARAM_PREFIX + "hpc_sync_script")
s3_sync_script = getSSMParam(SSM_PARAM_PREFIX + "s3_sync_script")
lims_update_script = getSSMParam(SSM_PARAM_PREFIX + "lims_update_script")
hpc_sync_dest_host = getSSMParam(SSM_PARAM_PREFIX + "hpc_sync_dest_host") 
HPC_SSH_USER = getSSMParam(SSM_PARAM_PREFIX + "hpc_sync_ssh_user")
aws_profile = getSSMParam(SSM_PARAM_PREFIX + "aws_profile")
s3_sync_dest_bucket = getSSMParam(SSM_PARAM_PREFIX + "s3_sync_dest_bucket")


def build_command(script_case, input_data):
    """
    Builds the remote shell script command to run given the use case, input data and the task token
    to be used to terminate the waiting activity of the Step Function state.
    """

    if input_data.get('runfolder'):
        runfolder = input_data['runfolder']
        print(f"runfolder: {runfolder}")
    else:
        raise ValueError('A runfolder parameter is mandatory!')

    runfolder_path = os.path.join(runfolder_base_path, runfolder)
    bcl2fastq_out_path = os.path.join(bcl2fastq_base_path, runfolder)

    execution_timneout = '600'  # time (sec) before the command is timed out
    command = f"su - limsadmin -c '"

    if script_case == "runfolder_check":
        execution_timneout = '60'
        command += f" DEPLOY_ENV={DEPLOY_ENV}"
        command += f" {runfolder_check_script} {runfolder_path}"
    elif script_case == "samplesheet_check":
        samplesheet_path = os.path.join(runfolder_base_path, runfolder, "SampleSheet.csv")
        command += f" conda activate pipeline &&"
        command += f" DEPLOY_ENV={DEPLOY_ENV} AWS_PROFILE={aws_profile}"
        command += f" python {samplesheet_check_script} {samplesheet_path} {runfolder}"
    elif script_case == "bcl2fastq":
        execution_timneout = '36000'
        command += f" DEPLOY_ENV={DEPLOY_ENV} AWS_PROFILE={aws_profile}"
        command += f" {bcl2fastq_script} -R {runfolder_path} -n {runfolder} -o {bcl2fastq_out_path}"
    elif script_case == "create_runfolder_checksums":
        execution_timneout = '36000'
        command += f" DEPLOY_ENV={DEPLOY_ENV} AWS_PROFILE={aws_profile}"
        command += f" {checksum_script} runfolder {runfolder_path} {runfolder}"
    elif script_case == "create_fastq_checksums":
        execution_timneout = '36000'
        command += f" DEPLOY_ENV={DEPLOY_ENV} AWS_PROFILE={aws_profile}"
        command += f" {checksum_script} bcl2fastq {bcl2fastq_out_path} {runfolder}"
    elif script_case == "sync_runfolder_to_hpc":
        execution_timneout = '10800'
        command += f" DEPLOY_ENV={DEPLOY_ENV} AWS_PROFILE={aws_profile}"
        command += f" {hpc_sync_script} -d {hpc_sync_dest_host} -u {HPC_SSH_USER} -p {hpc_dest_base_path}"
        command += f" -s {runfolder_path} -x Data -x Thumbnail_Images -n {runfolder}"
    elif script_case == "sync_fastqs_to_hpc":
        execution_timneout = '36000'
        dest_path = os.path.join(hpc_dest_base_path, runfolder)
        command += f" DEPLOY_ENV={DEPLOY_ENV} AWS_PROFILE={aws_profile}"
        command += f" {hpc_sync_script} -d {hpc_sync_dest_host} -u {HPC_SSH_USER} -p {dest_path}"
        command += f" -s {bcl2fastq_out_path} -n {runfolder}"
    elif script_case == "sync_runfolder_to_s3":
        execution_timneout = '10800'
        command += f" DEPLOY_ENV={DEPLOY_ENV} AWS_PROFILE={aws_profile}"
        command += f" {s3_sync_script} -b {s3_sync_dest_bucket} -n {runfolder}"
        command += f" -d {runfolder} -s {runfolder_path} -x Data/* -x Thumbnail_Images/*"
    elif script_case == "sync_fastqs_to_s3":
        execution_timneout = '36000'
        command += f" DEPLOY_ENV={DEPLOY_ENV} AWS_PROFILE={aws_profile}"
        command += f" {s3_sync_script} -b {s3_sync_dest_bucket} -n {runfolder}"
        command += f" -d {runfolder}/{runfolder} -s {bcl2fastq_out_path} -f"
    elif script_case == "google_lims_update":
        execution_timneout = '600'
        command += f" conda activate pipeline &&"
        command += f" DEPLOY_ENV={DEPLOY_ENV}"
        command += f" python {lims_update_script} {runfolder}"
    else:
        print("Unsupported script_case! Should do something sensible here....")
        raise ValueError("No valid execution script!")
    command += "'"

    print(f"Script command; {command}")

    return command, execution_timneout


def aws_session(role_arn=None, session_name='my_session'):
    """
    If role_arn is given assumes a role and returns boto3 session
    otherwise return a regular session with the current IAM user/role
    """
    if role_arn:
        client = boto3.client('sts')
        response = client.assume_role(RoleArn=role_arn, RoleSessionName=session_name)
        session = boto3.Session(
            aws_access_key_id=response['Credentials']['AccessKeyId'],
            aws_secret_access_key=response['Credentials']['SecretAccessKey'],
            aws_session_token=response['Credentials']['SessionToken'])
        return session
    else:
        return boto3.Session()


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
    print(f"...for activity: {WAIT_FOR_ACTIVITY_ARN} and lambda: {context.function_name}")
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
                                                   input_data=event['input'])

    session_assumed = aws_session(role_arn=BASTION_SSM_ROLE_ARN, session_name='bastion_session')
    response = session_assumed.client('ssm').send_command(
        InstanceIds=[ssm_instance_id],
        DocumentName=SSM_DOC_NAME,
        Parameters={"commands": [script_command], "executionTimeout": [script_timeout],
                    "taskToken": [task_token], "deployEnv": [DEPLOY_ENV]},
        CloudWatchOutputConfig={'CloudWatchOutputEnabled': True}, )

    command_id = response['Command']['CommandId']
    print(f"Command ID: {command_id}")
