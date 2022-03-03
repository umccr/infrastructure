import boto3
import json
import logging
import eb_util as util
import schema.weslaunchrequest as wlr

logger = logging.getLogger()
logger.setLevel(logging.INFO)
lambda_client = boto3.client('lambda')


def create_sqs_event(workflow_name: str, status: str):
    return {
        "Records": [
            {
                "messageId": "123456789",
                "receiptHandle": "123456789/123/foo/bar",
                "body": json.dumps(create_wes_ens_body(workflow_name=workflow_name, status=status)),
                "attributes": {
                    "ApproximateReceiveCount": "1",
                    "SentTimestamp": "1625004165382",
                    "SenderId": "123456789",
                    "ApproximateFirstReceiveTimestamp": "1625004165389"
                },
                "messageAttributes": {
                    "subscription-urn": {
                        "stringValue": "urn:ilmn:igp:us-east-1:123456789:subscription:sub.1234",
                        "stringListValues": [],
                        "binaryListValues": [],
                        "dataType": "String"
                    },
                    "spring_json_header_types": {
                        "stringValue": "some_irrelevant_string",
                        "stringListValues": [],
                        "binaryListValues": [],
                        "dataType": "String"
                    },
                    "action": {
                        "stringValue": "Succeeded",  # hardcoded as we simulate successful WES runs
                        "stringListValues": [],
                        "binaryListValues": [],
                        "dataType": "String"
                    },
                    "type": {
                        "stringValue": "wes.runs",  # hardcoded as we are simulating only this kind of event
                        "stringListValues": [],
                        "binaryListValues": [],
                        "dataType": "String"
                    },
                    "actionDate": {
                        "stringValue": "2021-06-29T22:02:23.391Z",
                        "stringListValues": [],
                        "binaryListValues": [],
                        "dataType": "String"
                    },
                    "contentType": {
                        "stringValue": "application/json",
                        "stringListValues": [],
                        "binaryListValues": [],
                        "dataType": "String"
                    },
                    "contentVersion": {
                        "stringValue": "1",
                        "stringListValues": [],
                        "binaryListValues": [],
                        "dataType": "String"
                    },
                    "producedBy": {
                        "stringValue": "WorkflowExecutionService",
                        "stringListValues": [],
                        "binaryListValues": [],
                        "dataType": "String"
                    },
                    "__TypeId__": {
                        "stringValue": "com.illumina.stratus.wes.worker.model.kafka.WesWorkflowRunEvent",
                        "stringListValues": [],
                        "binaryListValues": [],
                        "dataType": "String"
                    }
                },
                "md5OfMessageAttributes": "123456789",
                "md5OfBody": "123456789",
                "eventSource": "aws:sqs",
                "eventSourceARN": "arn:aws:sqs:ap-southeast-2:123456789:some-sqs-queue",
                "awsRegion": "ap-southeast-2"
            }
        ]
    }


def create_wes_ens_body(workflow_name, status):
    return {
        "Timestamp": "2021-06-29T22:02:23.391Z",
        "EventType": "RunSucceeded",
        "EventDetails": {},
        "WorkflowRun": {
            "TenantId": "123456789",
            "Status": status,
            "TimeModified": "2021-06-29T22:01:43.129128Z",
            "Acl": [
                "cid:123456789",
                "tid:123456789"
            ],
            "WorkflowVersion": {
                "Id": "wfv.123456789",
                "TimeModified": "2021-04-30T14:38:21.777722Z",
                "Language": {
                    "Name": "CWL"
                },
                "TenantId": "123456789",
                "Acl": [
                    "tid:123456789",
                    "cid:123456789",
                    "wid:123456789"
                ],
                "Timestamp": "2021-04-30T14:38:21.777722Z",
                "MessageKey": "wfv.123456789",
                "Version": "3.7.5--1.3.5-43a0e8a",
                "Urn": "urn:ilmn:iap:aps2:123456789:workflowversion:wfv.123456789#3.7.5--1.3.5-43a0e8a",
                "Status": "Draft",
                "TimeCreated": "2021-04-22T10:13:22.770106Z",
                "CreatedByClientId": "iap-aps2",
                "CreatedBy": "123456789",
                "Href": "https://aps2.platform.illumina.com/v1/workflows/wfl.123456789/versions/3.7.5--1.3.5-43a0e8a",
                "ModifiedBy": "123456789"
            },
            "Id": "wfr.123456789",
            "Urn": f"urn:ilmn:iap:aps2:123456789:workflowrun:wfr.123456789#{workflow_name}",
            "TimeCreated": "2021-06-29T17:17:14.438741Z",
            "StatusSummary": "",
            "TimeStarted": "2021-06-29T17:17:16.404574Z",
            "CreatedByClientId": "iap-aps2",
            "CreatedBy": "123456789",
            "Href": "https://aps2.platform.illumina.com/v1/workflows/runs/wfr.123456789",
            "TimeStopped": "2021-06-29T22:02:23.391Z",
            "ModifiedBy": "bc99b89c-3bb7-334b-80d1-20ef9e65f0b0",
            "Name": workflow_name
        },
        "Acl": [
            "cid:123456789",
            "tid:123456789"
        ],
        "MessageKey": "wfr.123456789",
        "PreviousEventId": 123456788,
        "EventId": 123456789,
        "Name": workflow_name
    }


def handler(event, context):
    # Log the received event in CloudWatch
    logger.info("Starting wes_launcher lambda")
    logger.info(f"Received event: {json.dumps(event)}")

    # TODO: send fake WES-SQS event with real structure (simulates real ICA WES response)
    payload = event.get(util.BusEventKey.DETAIL.value)
    wlr_event: wlr.Event = wlr.Marshaller.unmarshall(payload, typeName=wlr.Event)
    # ignore other values that would be used for a real WES launch

    logger.info("Creating ENS event")
    ens_event = create_sqs_event(
        workflow_name=wlr_event.workflow_run_name,
        status="Pending")

    # forward event payload to ens lambda
    logger.info("Sending ENS event to ens_event_manager:")
    logger.info(json.dumps(ens_event))
    response = lambda_client.invoke(
        FunctionName='UmccrEventBus_ens_event_manager',  # TODO: hardcoded for mock impl
        InvocationType='Event',
        Payload=json.dumps(ens_event)
    )
    logger.info(f"Lambda invocation response: {response}")
    logger.info("All done.")
