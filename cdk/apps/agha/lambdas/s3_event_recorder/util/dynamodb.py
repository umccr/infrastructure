import os.path
import logging
import boto3
from boto3.dynamodb.conditions import Key, Attr
import util.agha as agha


from typing import List
from enum import Enum

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TABLE_NAME = 'AghaGdrObjects'
DYNAMODB_RESOURCE = ''
DATE_EXCEPTIONS = ["2020-02-30"]


class DbAttribute(Enum):
    BUCKET = "bucket"
    S3KEY = "s3key"
    ETAG = "etag"
    FILENAME = "filename"
    FILETYPE = "filetype"
    FLAGSHIP = "flagship"
    CHECKSUM_PROVIDED = "checksum_provided"
    CHECKSUM_CALCULATED = "checksum_calculated"
    HAS_INDEX = "has_index"
    AGHA_STUDY_ID = "agha_study_id"
    QUICK_CHECK_STATUS = "quick_check_status"

    def __str__(self):
        return self.value


class DynamoDbRecord:
    """
    The DynamoDB table is configured with a mandatory composite key composed of two elements:
    - bucket: the name of the S3 bucket (HASH) as partition key
    - s3key: the object key within that bucket (RANGE) as unique object identifier
    All other attributes are optional (although some can automatically be derived from the object key)
    """

    def __init__(self,
                 bucket: str,
                 s3key: str,
                 etag: str = "",
                 checksum_provided: str = "",
                 checksum_calculated: str = "",
                 has_index: str = "",
                 study_id: str = "",
                 quick_ckeck:str = ""):
        self.bucket = bucket
        self.s3key = s3key
        self.etag = etag
        self.filename = os.path.basename(s3key)
        self.filetype = agha.get_file_type(s3key).value
        self.flagship = agha.get_flagship_from_key(s3key)
        self.checksum_provided = checksum_provided
        self.checksum_calculated = checksum_calculated
        self.has_index = has_index
        self.study_id = study_id
        self.quick_ckeck = quick_ckeck

    def to_dict(self):
        return {
            DbAttribute.BUCKET.value: self.bucket,
            DbAttribute.S3KEY.value: self.s3key,
            DbAttribute.ETAG.value: self.etag,
            DbAttribute.FILENAME.value: self.filename,
            DbAttribute.FILETYPE.value: self.filetype,
            DbAttribute.FLAGSHIP.value: self.flagship,
            DbAttribute.CHECKSUM_PROVIDED.value: self.checksum_provided,
            DbAttribute.CHECKSUM_CALCULATED.value: self.checksum_calculated,
            DbAttribute.HAS_INDEX.value: self.has_index,
            DbAttribute.AGHA_STUDY_ID.value: self.study_id,
            DbAttribute.QUICK_CHECK_STATUS.value: self.quick_ckeck
        }

    def __str__(self):
        return f"s3://{self.bucket}/{self.s3key}"


def create_gdr_table():
    ddb = get_resource()
    table = ddb.create_table(
        TableName=TABLE_NAME,
        KeySchema=[
            {
                'AttributeName': DbAttribute.BUCKET.value,
                'KeyType': 'HASH'
            },
            {
                'AttributeName': DbAttribute.S3KEY.value,
                'KeyType': 'RANGE'
            }
        ],
        AttributeDefinitions=[
            {
                'AttributeName': DbAttribute.BUCKET.value,
                'AttributeType': 'S'
            },
            {
                'AttributeName': DbAttribute.S3KEY.value,
                'AttributeType': 'S'
            }
        ],
        BillingMode='PAY_PER_REQUEST',
        Tags=[
            {
                'Key': 'Stack',
                'Value': 'agha'
            },
            {
                'Key': 'UseCase',
                'Value': 'AghaValidation'
            }
        ]
    )

    return table


def delete_gdr_table():
    ddb = get_resource()
    tbl = ddb.Table(TABLE_NAME)
    resp = tbl.delete()
    return resp


def get_resource():
    global DYNAMODB_RESOURCE
    if DYNAMODB_RESOURCE:
        return DYNAMODB_RESOURCE
    else:
        if os.getenv('AWS_ENDPOINT'):
            logger.info("Using local DynamoDB instance")
            DYNAMODB_RESOURCE = boto3.resource(service_name='dynamodb', endpoint_url=os.getenv('AWS_ENDPOINT'))
        else:
            logger.info("Using AWS DynamoDB instance")
            DYNAMODB_RESOURCE = boto3.resource(service_name='dynamodb')
        return DYNAMODB_RESOURCE


def batch_write_records(records: List[DynamoDbRecord]):
    ddb = get_resource()
    tbl = ddb.Table(TABLE_NAME)
    with tbl.batch_writer() as batch:
        for record in records:
            batch.put_item(Item=record.to_dict())


def batch_delete_records(records: List[DynamoDbRecord]):
    ddb = get_resource()
    tbl = ddb.Table(TABLE_NAME)
    with tbl.batch_writer() as batch:
        for record in records:
            batch.delete_item(Key={
                DbAttribute.BUCKET.value: record.bucket,
                DbAttribute.S3KEY.value: record.s3key
            })


def write_record(record: DynamoDbRecord) -> dict:
    ddb = get_resource()
    tbl = ddb.Table(TABLE_NAME)

    resp = tbl.put_item(Item=record, ReturnValues='UPDATED_OLD')
    return resp


def get_all_records():
    ddb = get_resource()
    tbl = ddb.Table(TABLE_NAME)
    response = tbl.scan()
    result = response['Items']

    while 'LastEvaluatedKey' in response:
        response = tbl.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
        result.extend(response['Items'])

    return result


def db_response_to_record(db_dict: dict) -> DynamoDbRecord:
    retval = DynamoDbRecord(
        bucket=db_dict[DbAttribute.BUCKET.value],
        s3key=db_dict[DbAttribute.S3KEY.value]
    )
    if DbAttribute.ETAG.value in db_dict:
        retval.etag = db_dict[DbAttribute.ETAG.value]
    if DbAttribute.CHECKSUM_PROVIDED.value in db_dict:
        retval.etag = db_dict[DbAttribute.CHECKSUM_PROVIDED.value]
    if DbAttribute.CHECKSUM_CALCULATED.value in db_dict:
        retval.etag = db_dict[DbAttribute.CHECKSUM_CALCULATED.value]
    if DbAttribute.HAS_INDEX.value in db_dict:
        retval.etag = db_dict[DbAttribute.HAS_INDEX.value]
    if DbAttribute.AGHA_STUDY_ID.value in db_dict:
        retval.etag = db_dict[DbAttribute.AGHA_STUDY_ID.value]
    if DbAttribute.QUICK_CHECK_STATUS.value in db_dict:
        retval.etag = db_dict[DbAttribute.QUICK_CHECK_STATUS.value]

    return retval


def get_record(bucket: str, s3key: str) -> DynamoDbRecord:
    ddb = get_resource()
    tbl = ddb.Table(TABLE_NAME)

    expr = Key(DbAttribute.BUCKET.value).eq(bucket) & Key(DbAttribute.S3KEY.value).begins_with(s3key)

    resp = tbl.get_item(expr)
    if not 'Item' in resp:
        raise ValueError(f"No record found for s3://{bucket}/{s3key}")

    return db_response_to_record(resp['Item'])


def get_by_prefix(bucket: str, prefix: str):
    ddb = get_resource()
    tbl = ddb.Table(TABLE_NAME)

    expr = Key(DbAttribute.BUCKET.value).eq(bucket) & Key(DbAttribute.S3KEY.value).begins_with(prefix)

    response = tbl.query(
        KeyConditionExpression=expr
    )
    result = response['Items']

    while 'LastEvaluatedKey' in response:
        response = tbl.query(
            KeyConditionExpression=expr,
            ExclusiveStartKey=response['LastEvaluatedKey']
        )
        result.extend(response['Items'])

    return result


def get_pending_validation(bucket: str, prefix: str = None):
    ddb = get_resource()
    tbl = ddb.Table(TABLE_NAME)

    if prefix:
        key_expr = Key(DbAttribute.BUCKET.value).eq(bucket) & Key(DbAttribute.S3KEY.value).begins_with(prefix)
    else:
        key_expr = Key(DbAttribute.BUCKET.value).eq(bucket)
    filter_expr = Attr(DbAttribute.QUICK_CHECK_STATUS.value).eq("Pending")

    response = tbl.query(
        KeyConditionExpression=key_expr,
        FilterExpression=filter_expr
    )
    result = response['Items']

    while 'LastEvaluatedKey' in response:
        response = tbl.query(
            KeyConditionExpression=key_expr,
            FilterExpression=filter_expr,
            ExclusiveStartKey=response['LastEvaluatedKey']
        )
        result.extend(response['Items'])

    return result


def update_store_record(record: DynamoDbRecord):
    """
    A store record should only be created when a validated staging record/file is transferred from the
    STAGING to the STORE bucket.
    As such we want to make sure the STORE record is updated with the metadata from the STAGING record.
    :param record: the STORE record to update
    :return: a dict containing any 'old' values that have been replaced with this update
    """
    if record.bucket != agha.STORE_BUCKET:
        logger.warning(f"Attempt to update non-STORE record! Skipping {record}")
        return

    # get the corresponding STAGING record to retrieve the (validation) metadata from
    # (there should always be one, unless the object keys have been changed during the STAGING -> STORE transfer)
    staging_record = get_record(agha.STAGING_BUCKET, record.s3key)

    # make sure the s3 object keys are the same
    if not staging_record:
        logger.warning(f"Store and Staging records don't have the same object key! Skipping {record}!")
        return

    # Copy the validation metadata from the staging record to the store record
    record.checksum_calculated = staging_record.checksum_calculated
    record.checksum_provided = staging_record.checksum_provided
    record.has_index = staging_record.has_index
    record.study_id = staging_record.study_id
    record.quick_ckeck = staging_record.quick_ckeck

    # persist the record
    resp = write_record(record=record)
    return resp

