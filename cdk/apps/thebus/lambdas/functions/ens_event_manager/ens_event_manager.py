import json
from datetime import datetime
import logging
from enum import Enum
import eb_util as util
import schema.sequencerunstatechange as srsc
import schema.workflowrunstatechange as wrsc

logger = logging.getLogger()
logger.setLevel(logging.INFO)
# TODO: split into separate lambdas? each responsible for s specific ENS event type, each with it's own ENS subscription


class ENSEventType(Enum):
    """
    REF:
    https://iap-docs.readme.io/docs/ens_available-events
    https://github.com/umccr-illumina/stratus/issues/22#issuecomment-628028147
    https://github.com/umccr-illumina/stratus/issues/58
    https://iap-docs.readme.io/docs/upload-instrument-runs#run-upload-event
    """
    GDS_FILES = "gds.files"
    BSSH_RUNS = "bssh.runs"
    WES_RUNS = "wes.runs"

    def __str__(self):
        return self.value

    def __repr__(self):
        return f"{type(self).__name__}.{self}"


SUPPORTED_ENS_TYPES = [
    ENSEventType.BSSH_RUNS.value,
    ENSEventType.GDS_FILES.value,
    ENSEventType.WES_RUNS.value,
]


def handle_wes_runs_event(event):
    logger.info("Handling wes.runs event")
    event_action = event['messageAttributes']['action']['stringValue']  # TODO: check! should probably be 'updated'
    message_body = json.loads(event['body'])

    # TODO: convert SQS/ENS event into corresponding Portal event
    event_status = message_body['EventType']  # RunSucceeded
    event_time = message_body['Timestamp']
    workflow_name = message_body['Name']
    workflow_id = message_body['WorkflowRun']['Id']  # wfr.23487yq4508
    workflow_status = message_body['WorkflowRun']['Status']  # Succeeded

    # Convert Pending status of WES launcher to Succeeded (simulating a successful WES run)
    if workflow_status == "Pending":
        workflow_status = "Succeeded"
    else:
        # We are receiving mock events from the WES launcher directly, those have all Pending status
        raise ValueError("Received non Pending WES run status! Only expect Pending at this point.")

    wrsc_event = wrsc.Event(
        workflow_run_name=workflow_name,
        workflow_run_id=workflow_id,
        status=workflow_status,
        timestamp=event_time
    )

    logger.info(f"Emitting {util.EventType.SRSC} event {wrsc_event}")
    util.send_event_to_bus_schema(
        event_type=util.EventType.WRSC,
        event_source=util.EventSource.ENS_HANDLER,
        event_payload=wrsc_event)


def handle_gds_file_event(event):
    logger.info("Handling gds.files event")
    event_action = event['messageAttributes']['action']['stringValue']

    # message_body = json.loads(event['body'])
    # TODO: also check if report and create a report event

    if event_action == 'deleted':
        logger.info(f"A file was removed.")
        # delete DB file record
    else:
        logger.info(f"A file was added/updated.")
        # create/update DB file record


def handle_bssh_runs_event(event):
    logger.info("Handling bssh.runs event")
    event_action = event['messageAttributes']['action']['stringValue']
    if event_action != 'statuschanged':
        raise ValueError(f"Unexpected event action: {event_action}")
    message_body = json.loads(event['body'])

    # TODO: check difference between run name and instrument run ID
    srn = message_body['name']
    iri = message_body['instrumentRunId']
    if srn != iri:
        raise ValueError(f"Sequence run name and instrumentRunId are not the same! {srn} != {iri}")

    ev = srsc.Event(
        sequence_run_name=srn,
        sequence_run_id=message_body['id'],
        gds_folder_path=message_body['gdsFolderPath'],
        gds_volume_name=message_body['gdsVolumeName'],
        status=message_body['status'],
        timestamp=datetime.utcnow())

    logger.info(f"Emitting {util.EventType.SRSC} event {ev}")
    util.send_event_to_bus_schema(
        event_type=util.EventType.SRSC,
        event_source=util.EventSource.ENS_HANDLER,
        event_payload=ev)


def handler(event, context):
    # Log the received event in CloudWatch
    logger.info("Starting ens_event_manager")
    logger.info(json.dumps(event))

    # An SQS event can carry multiple Records, each one may be a different ENS event
    for message in event['Records']:
        event_type = message['messageAttributes']['type']['stringValue']
        if event_type not in SUPPORTED_ENS_TYPES:
            logger.warning(f"Skipping unsupported IAP ENS type: {event_type}")
            continue

        if event_type == ENSEventType.WES_RUNS.value:
            handle_wes_runs_event(message)

        if event_type == ENSEventType.BSSH_RUNS.value:
            handle_bssh_runs_event(message)

        if event_type == ENSEventType.GDS_FILES.value:
            handle_gds_file_event(message)

    logger.info("All done.")
