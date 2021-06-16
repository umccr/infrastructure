import os
import io
import re
import json
import boto3
import http.client
import pandas as pd

MANIFEST_REQUIRED_COLUMNS = ('filename', 'checksum', 'agha_study_id')
AWS_REGION = boto3.session.Session().region_name
STAGING_BUCKET = os.environ.get('STAGING_BUCKET')
SLACK_HOST = os.environ.get('SLACK_HOST')
SLACK_CHANNEL = os.environ.get('SLACK_CHANNEL')
MANAGER_EMAIL = os.environ.get('MANAGER_EMAIL')
SENDER_EMAIL = os.environ.get('SENDER_EMAIL')
HEADERS = {'Content-Type': 'application/json'}
EMAIL_SUBJECT = '[AGHA service] Submission received'
aws_id_pattern = '[0-9A-Z]{21}'
email_pattern = '[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+'
USER_RE = re.compile(f"AWS:({aws_id_pattern})")
SSO_RE = re.compile(f"AWS:({aws_id_pattern}):({email_pattern})")

s3_client = boto3.client('s3')
ssm_client = boto3.client('ssm')
iam_client = boto3.client('iam')
ses_client = boto3.client('ses',region_name=AWS_REGION)
SLACK_WEBHOOK_ENDPOINT = ssm_client.get_parameter(
    Name='/slack/webhook/endpoint',
    WithDecryption=True
    )['Parameter']['Value']


def get_name_email_from_principalid(principal_id):
    if USER_RE.fullmatch(principal_id):
        user_id = re.search(USER_RE, principal_id).group(1)
        user_list = iam_client.list_users()
        for user in user_list['Users']:
            if user['UserId'] == user_id:
                username = user['UserName']
        user_details = iam_client.get_user(UserName=username)
        tags = user_details['User']['Tags']
        for tag in tags:
            if tag['Key'] == 'email':
                email = tag['Value']
        return username, email
    elif SSO_RE.fullmatch(principal_id):
        email = re.search(SSO_RE, principal_id).group(2)
        username = email.split('@')[0]
        return username, email
    else:
        print(f"Unsupported principalId format")
        return None, None


def make_email_body_html(submission, submitter, messages):
    body_html = f"""
    <html>
        <head></head>
        <body>
            <h1>{submission}</h1>
            <p>New AGHA submission rceived from {submitter}</p>
            <p>This is a generated message, please do not reply</p>
            <h2>Quick validation</h2>
            PLACEHOLDER
        </body>
    </html>"""
    insert = ''
    for msg in messages:
        insert += f"{msg}<br>\n"
    body_html = body_html.replace('PLACEHOLDER', insert)
    return body_html


def send_email(recipients, sender, subject_text, body_html):
    try:
        #Provide the contents of the email.
        response = ses_client.send_email(
            Destination={
                'ToAddresses': recipients,
            },
            Message={
                'Subject': {
                    'Charset': 'utf8',
                    'Data': subject_text,
                },
                'Body': {
                    'Html': {
                        'Charset': 'utf8',
                        'Data': body_html,
                    }
                }
            },
            Source=sender,
        )
    # Display an error if something goes wrong
    except ClientError as e:
        return(e.response['Error']['Message'])
    else:
        return("Email sent! Message ID:" + response['MessageId'] )


def call_slack_webhook(topic, title, message):
    connection = http.client.HTTPSConnection(SLACK_HOST)

    post_data = {
        "channel": SLACK_CHANNEL,
        "username": "Notice from AWS",
        "text": "*" + topic + "*",
        "icon_emoji": ":aws_logo:",
        "attachments": [{
            "title": title,
            "text": message
        }]
    }

    connection.request("POST", SLACK_WEBHOOK_ENDPOINT, json.dumps(post_data), HEADERS)
    response = connection.getresponse()
    connection.close()

    return response.status


def get_manifest_df(prefix: str):
    global STAGING_BUCKET
    print(f"Getting manifest from : {STAGING_BUCKET}/{prefix}")
    obj = s3_client.get_object(Bucket=STAGING_BUCKET, Key=f"{prefix}/manifest.txt")
    df = pd.read_csv(io.BytesIO(obj['Body'].read()), sep='\t', encoding='utf8')
    return df


def manifest_headers_ok(manifest_df, msgs):
    is_ok = True

    if manifest_df is None:
        msgs.append("No manifest to read!")
        return False

    for col_name in MANIFEST_REQUIRED_COLUMNS:
        if col_name not in manifest_df.columns:
            is_ok = False
            msgs.append(f"Column '{col_name}' not found in manifest!")
    return is_ok


def get_listing(prefix: str):
    # get the S3 object listing for the prefix
    files = list()
    file_batch = s3_client.list_objects_v2(
        Bucket=STAGING_BUCKET,
        Prefix=prefix
    )
    if file_batch.get('Contents'):
        files.extend(extract_filenames(file_batch['Contents']))
    while file_batch['IsTruncated']:
        token = file_batch['NextContinuationToken']
        file_batch = s3_client.list_objects_v2(
            Bucket=STAGING_BUCKET,
            Prefix=prefix,
            ContinuationToken=token
        )
        files.extend(extract_filenames(file_batch['Contents']))

    return files


def extract_filenames(listing: list):
    filenames = list()
    for item in listing:
        filenames.append(os.path.basename(item['Key']))
    return filenames


def handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    validation_messages = list()

    message = event['Records'][0]['Sns']['Message']
    print(f"Extracted message: {message}")
    message = json.loads(message)

    bucket_name = message["Records"][0]["s3"]["bucket"]["name"]
    if bucket_name != STAGING_BUCKET:
        raise ValueError(f"Buckets don't match received {bucket_name}, expected {STAGING_BUCKET}")

    obj_key = message["Records"][0]["s3"]["object"]["key"]
    submission_prefix = os.path.dirname(obj_key)
    print(f"Submission with prefix: {submission_prefix}")
    validation_messages.append(f"Validation messages:")

    msg_record = msg_record = message['Records'][0]
    if msg_record.get('eventSource') == 'aws:s3' and msg_record.get('userIdentity'):
        principal_id = msg_record['userIdentity']['principalId']
        name, email = get_name_email_from_principalid(principal_id)
        print(f"Extracted name/email: {name}/{email}")

    # Build validation messages
    try:
        manifest_df = get_manifest_df(submission_prefix)
    except Exception as e:
        print(f"Error trying convert manifest into DataFrame: {e}")
        validation_messages.append(f"Error trying convert manifest into DataFrame: {e}")

    if manifest_headers_ok(manifest_df, validation_messages):
        message = f"Entries in manifest: {len(manifest_df)}"
        print(message)
        validation_messages.append(message)

        s3_files = set(get_listing(submission_prefix))
        message = f"Entries on S3 (including manifest): {len(s3_files)}"
        print(message)
        validation_messages.append(message)

        manifest_files = set(manifest_df['filename'].to_list())
        files_not_on_s3 = manifest_files.difference(s3_files)
        message = f"Entries in manifest, but not on S3: {len(files_not_on_s3)}"
        print(message)
        validation_messages.append(message)

        files_not_in_manifeset = s3_files.difference(manifest_files)
        message = f"Entries on S3, but not in manifest: {len(files_not_in_manifeset)}"
        print(message)
        validation_messages.append(message)

        files_in_both = manifest_files.intersection(s3_files)
        message = f"Entries common in manifest and S3: {len(files_in_both)}"
        print(message)
        validation_messages.append(message)

    print(f"Sending validation messages to Slack and Email.")
    print(validation_messages)
    slack_response = call_slack_webhook(
        topic="AGHA submission quick validation",
        title=f"Submission: {submission_prefix} ({name})",
        message='\n'.join(validation_messages)
    )
    print(f"Slack call response: {slack_response}")

    print(f"Sending email to {name}/{email}")
    response = send_email(
        recipients=[MANAGER_EMAIL, email],
        sender=SENDER_EMAIL,
        subject_text=EMAIL_SUBJECT,
        body_html=make_email_body_html(
            submission=submission_prefix,
            submitter=name,
            messages=validation_messages)
    )
    print(f"Email send response: {response}")
