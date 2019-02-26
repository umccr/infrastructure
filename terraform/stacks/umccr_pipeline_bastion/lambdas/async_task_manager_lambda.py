import boto3
import os
import json

EVENT_SOURCE = "aws.ssm"
STATUS_SUCCESS = "Success"
DETAIL_TYPE_CHANGE = "EC2 Command Status-change Notification"  # The cloundwatch rule should make sure we only get events that match this!
SSM_DOC_NAME = os.environ.get("SSM_DOC_NAME")
DEV_SFN_ROLE_ARN = os.environ.get("DEV_SFN_ROLE_ARN")
PROD_SFN_ROLE_ARN = os.environ.get("PROD_SFN_ROLE_ARN")


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
    # initial checks and parameter extraction

    if event['source'] != EVENT_SOURCE:
        raise ValueError(f"Expected event source to be {EVENT_SOURCE}, but it is {event['source']}!")
    if event['detail']['document-name'] != SSM_DOC_NAME:
        raise ValueError(f"Expected SSM document to be {SSM_DOC_NAME} but it is {event['detail']['document-name']}")
    if event['detail-type'] != DETAIL_TYPE_CHANGE:
        raise ValueError(f"Expected events of type {DETAIL_TYPE_CHANGE}, but it was {event['detail-type']}")

    # parameters are only avaible for the event type DETAIL_TYPE_CHANGE, other types, like invoction events
    # only carry the command ID, which would have to be mapped to a command description to be useful for reporting
    document_parameters = event['detail']['parameters']
    print("Document parameters: " + json.dumps(document_parameters))

    parameters = json.loads(document_parameters)
    task_token = parameters['taskToken'][0]
    deploy_env = parameters['deployEnv'][0]
    command_status = event['detail']['status']
    print("Token: " + task_token)
    print("Deploy env: " + deploy_env)
    print("Command status: " + command_status)

    if deploy_env == 'prod':
        session_assumed = aws_session(role_arn=PROD_SFN_ROLE_ARN, session_name='bastion_session')
        print("Assumed prod session")
    else:
        session_assumed = aws_session(role_arn=DEV_SFN_ROLE_ARN, session_name='bastion_session')
        print("Assumed dev session")
    tmp_client = session_assumed.client('stepfunctions')

    if command_status == STATUS_SUCCESS:
        print("Successful completed pipeline step.")
        tmp_client.send_task_success(taskToken=task_token, output='{"status":"success"}')
    else: 
        print("Failed to complete pipeline step.")
        tmp_client.send_task_failure(taskToken=task_token)
