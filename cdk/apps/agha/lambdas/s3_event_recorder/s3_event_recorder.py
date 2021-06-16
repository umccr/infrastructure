from typing import List

import logging
import json
from util.s3 import S3EventType, S3EventRecord, parse_s3_event
from util.agha import STAGING_BUCKET, STORE_BUCKET
from util.dynamodb import DynamoDbRecord
import util.dynamodb as dyndb


logger = logging.getLogger()
logger.setLevel(logging.INFO)


def convert_s3_record_to_db_record(s3_record: S3EventRecord) -> DynamoDbRecord:
    return DynamoDbRecord(bucket=s3_record.bucket_name,
                          s3key=s3_record.object_key,
                          etag=s3_record.etag)


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
    print(event)

    # we manually build a S3 event, which consists of a list of S3 Records
    s3_event_records = {
        "Records": []
    }

    # extract the S3 records from the SQS records
    sqs_records = event.get('Records')
    if not sqs_records:
        logger.warning("No Records in SQS event! Aborting.")
        logger.warning(json.dumps(event))
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
            s3_event_records['Records'].append(s3_record)

    handler(s3_event_records, context)


def handler(event, context):
    """
    Entry point for S3 event processing. An S3 event is essentially a dict with a list of S3 Records:
    {
        "Records": [
            {
                "eventSource": "aws:s3",
                "eventTime": "2021-06-07T00:33:42.818Z",
                "eventName": "ObjectCreated:Put",
                ...
                "s3": {
                    "bucket": {
                        "name": "bucket-name",
                        ...
                    },
                    "object": {
                        "key": "UMCCR-COUMN/SBJ00805/WGS/2021-06-03/umccrised/work/SBJ00805__SBJ00805_MDX210095_L2100459/oncoviruses/work/detect_viral_reference/host_unmapped_or_mate_unmapped_to_gdc.bam.bai",
                        "eTag": "d41d8cd98f00b204e9800998ecf8427e",
                        ...
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

    # convert S3 event payloads into more convenient S3EventRecords
    s3_event_records: List[S3EventRecord] = parse_s3_event(event)

    # split records by bucket and event type
    staging_db_records_create: List[DynamoDbRecord] = list()
    staging_db_records_delete: List[DynamoDbRecord] = list()
    store_db_records_create: List[DynamoDbRecord] = list()
    store_db_records_delete: List[DynamoDbRecord] = list()
    for s3_record in s3_event_records:
        if s3_record.bucket_name == STAGING_BUCKET:
            if s3_record.event_type == S3EventType.EVENT_OBJECT_CREATED:
                staging_db_records_create.append(convert_s3_record_to_db_record(s3_record))
            elif s3_record.event_type == S3EventType.EVENT_OBJECT_REMOVED:
                staging_db_records_delete.append(convert_s3_record_to_db_record(s3_record))
            else:
                logger.warning(f"Unsupported S3 event type {s3_record.event_type} for {s3_record}")
        elif s3_record.bucket_name == STORE_BUCKET:
            if s3_record.event_type == S3EventType.EVENT_OBJECT_CREATED:
                store_db_records_create.append(convert_s3_record_to_db_record(s3_record))
            elif s3_record.event_type == S3EventType.EVENT_OBJECT_REMOVED:
                store_db_records_delete.append(convert_s3_record_to_db_record(s3_record))
            else:
                logger.warning(f"Unsupported S3 event type {s3_record.event_type} for {s3_record}")
        else:
            logger.warning(f"Unsupported AGHA bucket: {s3_record.bucket_name}")
    logger.info(f"Found {len(staging_db_records_create)}/{len(staging_db_records_delete)} " +
                f"create/delete events for bucket {STAGING_BUCKET}")
    logger.info(f"Found {len(store_db_records_create)}/{len(store_db_records_delete)} " +
                f"create/delete events for bucket {STORE_BUCKET}")

    # in the staging bucket we just insert/delete DB records
    # When existing records get overwritten we may have to run validation again, but at least the DB records are
    # always up-to-date with the S3 content
    dyndb.batch_write_records(staging_db_records_create)
    dyndb.batch_delete_records(staging_db_records_delete)

    # TODO: ideally the staging to store transfer would happen automatically
    # records created in store should have a correspondence in staging and we want their metadata transferred
    # Ideally it would just be a change of the 'bucket' attribute
    dyndb.batch_write_records(store_db_records_create)
    for rec in store_db_records_create:
        dyndb.update_store_record(rec)
    dyndb.batch_delete_records(store_db_records_delete)

    return None
