import logging
import json
from enum import Enum
from typing import List


logger = logging.getLogger()
logger.setLevel(logging.INFO)


class S3EventType(Enum):
    """
    See S3 Supported Event Types
    https://docs.aws.amazon.com/AmazonS3/latest/dev/NotificationHowTo.html#supported-notification-event-types
    """
    EVENT_OBJECT_CREATED = 'ObjectCreated'
    EVENT_OBJECT_REMOVED = 'ObjectRemoved'
    EVENT_UNSUPPORTED = 'Unsupported'


class S3EventRecord:
    """
    A helper class for S3 event data passing and retrieval
    """

    def __init__(self, event_type, event_time, bucket_name, object_key, etag) -> None:
        self.event_type = event_type
        self.event_time = event_time
        self.bucket_name = bucket_name
        self.object_key = object_key
        self.etag = etag


def parse_s3_event(s3_event: dict) -> List[S3EventRecord]:
    """
    Parse raw SQS message bodies into S3EventRecord objects
    :param s3_event: the S3 event to be processed
    :return: list of S3EventRecord objects
    """
    s3_event_records = []

    if 'Records' not in s3_event.keys():
        logger.warning("No Records in message body!")
        logger.warning(json.dumps(s3_event))
        return

    records = s3_event['Records']

    for record in records:
        event_name = record['eventName']
        event_time = record['eventTime']
        s3 = record['s3']
        s3_bucket_name = s3['bucket']['name']
        s3_object_key = s3['object']['key']
        s3_object_etag = s3['object']['eTag']

        # Check event type
        if S3EventType.EVENT_OBJECT_CREATED.value in event_name:
            event_type = S3EventType.EVENT_OBJECT_CREATED
        elif S3EventType.EVENT_OBJECT_REMOVED.value in event_name:
            event_type = S3EventType.EVENT_OBJECT_REMOVED
        else:
            event_type = S3EventType.EVENT_UNSUPPORTED

        logger.debug(f"Found new event of type {event_type}")

        s3_event_records.append(S3EventRecord(event_type=event_type,
                                              event_time=event_time,
                                              bucket_name=s3_bucket_name,
                                              object_key=s3_object_key,
                                              etag=s3_object_etag))

    return s3_event_records
