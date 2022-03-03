import os
import logging
import json
import boto3

STAGING_BUCKET = os.environ.get('STAGING_BUCKET')
VALIDATION_LAMBDA_ARN = os.environ.get('VALIDATION_LAMBDA_ARN')
FOLDER_LOCK_LAMBDA_ARN = os.environ.get('FOLDER_LOCK_LAMBDA_ARN')
S3_RECORDER_LAMBDA_ARN = os.environ.get('S3_RECORDER_LAMBDA_ARN')

logger = logging.getLogger()
logger.setLevel(logging.INFO)

lambda_client = boto3.client('lambda')


def extract_s3_records_from_sqs_event(sqs_event):
    s3_recs = list()
    # extract the S3 records from the SQS records
    sqs_records = sqs_event.get('Records')
    if not sqs_records:
        logger.warning("No Records in SQS event! Aborting.")
        logger.warning(json.dumps(sqs_event))
        return

    for sqs_record in sqs_records:
        s3_event = json.loads(sqs_record.get('body'))
        if not s3_event:
            logger.warning("No S3 event body in SQS Record! Aborting.")
            logger.debug(f"SQS event: {sqs_record}")
            continue
        s3_records = s3_event.get('Records')
        if not s3_records:
            logger.warning("No Records in S3 event! Aborting.")
            logger.debug(f"S3 event: {s3_event}")
            continue
        for s3_record in s3_records:
            s3_recs.append(s3_record)

    return s3_recs


def extract_s3_records_from_sns_event(sns_event):
    # extract the S3 records from the SNS records
    s3_recs = list()
    sns_records = sns_event.get('Records')
    if not sns_records:
        logger.warning("No Records in SNS event! Aborting.")
        logger.warning(json.dumps(sns_event))
        return

    for sns_record in sns_records:
        payload = sns_record['Sns']['Message']
        s3_event = json.loads(payload)
        if not s3_event:
            logger.warning("No S3 event body in SNS Record! Aborting.")
            logger.debug(f"SNS event: {sns_record}")
            continue
        s3_records = s3_event.get('Records')
        if not s3_records:
            logger.warning("No Records in S3 event! Aborting.")
            logger.debug(f"S3 event: {s3_event}")
            continue
        for s3_record in s3_records:
            s3_recs.append(s3_record)

    return s3_recs


def call_lambda(lambda_arn: str, payload: dict):
    response = lambda_client.invoke(
        FunctionName=lambda_arn,
        InvocationType='Event',
        Payload=json.dumps(payload)
    )
    return response


def sqs_handler(event, context):
    """
    Entry point for S3 via SQS event processing. Wrapper for the handler method.
    A SQS event is essentially a dict with a list of (SQS) Records, each of which has a body element with a payload
    {
        "Records": [
            "body": "<sqs event payload>"
        ]
    }
    That body payload corresponds to the S3 event received by SQS. It, in turn, is essentially a
    dict with a list of (S3) Records (see handler(event, context) method).
    We extract all S3 records across all SQS records and collect them all up in one S3 event (Records list)
    for processing by the handler method.

    :param event: SQS event (with S3 event payload)
    :param context: not used
    """
    logger.info(f"Start processing S3 (via SQS) event:")
    logger.info(json.dumps(event))

    # we manually build a S3 event, which consists of a list of S3 Records
    s3_event_records = {
        "Records": extract_s3_records_from_sqs_event(event)
    }

    handler(s3_event_records, context)


def sns_handler(event, context):
    """
    Entry point for S3 via SNS event processing. Wrapper for the handler method.
    A SNS event is essentially a dict with a list of (SNS) Records, each of which has a 'Sns' element that contains
    a 'Message' element with the S3 event payload.
    {
        "Records": [
            {
                "EventSource": "aws:sns",
                "EventVersion": "1.0",
                "EventSubscriptionArn": "arn:...",
                "Sns": {
                    "Type": "Notification",
                    "MessageId": "d3523418-...-6d2f86a5f05e",
                    "TopicArn": "arn:...",
                    "Subject": "Amazon S3 Notification",
                    "Message": "<S3 event payload>",
                    "Timestamp": "2021-06-07T03:00:12.912Z",
                    "SignatureVersion": "1",
                    "Signature": "mXcR/D4e...eHpYx1w==",
                    "SigningCertUrl": "https://sns.ap-southeast-2.amazonaws.com/SimpleNotificationService-0...083a.pem",
                    "UnsubscribeUrl": "https://sns.ap-southeast-2.amazonaws.com/?Action=Unsubscribe&SubscriptionArn=...",
                    "MessageAttributes": {}
                }
            }
        ]
    }
    That payload corresponds to the S3 event received by SNS. It, in turn, is essentially a
    dict with a list of (S3) Records (see handler(event, context) method).
    We extract all S3 records across all SNS records and collect them all up in one S3 event (Records list)
    for processing by the handler method.

    :param event: SNS event (with S3 event payload(s))
    :param context: not used
    """
    logger.info(f"Start processing S3 (via SNS) event:")
    logger.info(json.dumps(event))

    # we manually build a S3 event, which consists of a list of S3 Records
    s3_event_records = {
        "Records": extract_s3_records_from_sns_event(event)
    }

    handler(s3_event_records, context)


def handler(event, context):
    """
    Entry point for S3 event processing. An S3 event is essentially a dict with a list of S3 Records:
    {
        "Records": [
            {
                 "eventVersion":"2.2",
                 "eventSource":"aws:s3",
                 "awsRegion":"us-west-2",
                 "eventTime":"1970-01-01T00:00:00.000Z",
                 "eventName":"event-type",
                 "userIdentity":{
                    "principalId":"Amazon-customer-ID-of-the-user-who-caused-the-event"
                 },
                 "requestParameters":{
                    "sourceIPAddress":"ip-address-where-request-came-from"
                 },
                 "responseElements":{
                    "x-amz-request-id":"Amazon S3 generated request ID",
                    "x-amz-id-2":"Amazon S3 host that processed the request"
                 },
                 "s3":{
                    "s3SchemaVersion":"1.0",
                    "configurationId":"ID found in the bucket notification configuration",
                    "bucket":{
                       "name":"bucket-name",
                       "ownerIdentity":{
                          "principalId":"Amazon-customer-ID-of-the-bucket-owner"
                       },
                       "arn":"bucket-ARN"
                    },
                    "object":{
                       "key":"object-key",
                       "size":"object-size",
                       "eTag":"object eTag",
                       "versionId":"object version if bucket is versioning-enabled, otherwise null",
                       "sequencer": "a string representation of a hexadecimal value used to determine event sequence"
                    }
                 },
                 "glacierEventData": {
                    "restoreEventData": {
                       "lifecycleRestorationExpiryTime": "1970-01-01T00:00:00.000Z",
                       "lifecycleRestoreStorageClass": "Source storage class for restore"
                    }
                 }
            },
            ...
        ]
    }

    :param event: S3 event
    :param context: not used
    """
    logger.info(f"Start processing S3 event:")
    logger.info(json.dumps(event))

    s3_records = event.get('Records')
    if not s3_records:
        logger.warning("Unexpected S3 event format, no Records! Aborting.")
        return

    # split event records into manifest and others
    # manifest events will be acted on by the validation and folder lock lambdas
    # non manifest events will be passed on to the recorder lambda for persisting into DynamoDB
    manifest_records = list()
    non_manifest_records = list()
    for s3_record in s3_records:
        # routing logic goes here
        event_name = s3_record['eventName']
        s3key: str = s3_record['s3']['object']['key']
        bucket: str = s3_record['s3']['bucket']['name']
        if s3key.endswith('manifest.txt') and 'ObjectCreated' in event_name:
            # we are only interested in new/created manifests of the staging bucket
            if bucket == 'agha-gdr-staging':
                manifest_records.append(s3_record)
        else:
            non_manifest_records.append(s3_record)

    logger.info(f"Processing {len(manifest_records)}/{len(non_manifest_records)} manifest/non-manifest events.")

    # call corresponding lambda functions
    # for manifest related events and others
    if len(manifest_records) > 0:
        v_res = call_lambda(VALIDATION_LAMBDA_ARN, {"Records": manifest_records})
        logger.info(f"Validation Lambda call response: {v_res}")
        fl_res = call_lambda(FOLDER_LOCK_LAMBDA_ARN, {"Records": manifest_records})
        logger.info(f"Folder Lock Lambda call response: {fl_res}")
    if len(non_manifest_records) > 0:
        ser_res = call_lambda(S3_RECORDER_LAMBDA_ARN, {"Records": non_manifest_records})
        logger.info(f"S3 Event Recorder Lambda call response: {ser_res}")
