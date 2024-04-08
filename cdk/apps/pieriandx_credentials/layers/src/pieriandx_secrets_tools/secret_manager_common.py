#!/usr/bin/env python3
import json
from base64 import b64decode
import typing
from os import environ
from typing import Any, Callable, Tuple
import boto3
from uuid import uuid4


if typing.TYPE_CHECKING:
    from mypy_boto3_secretsmanager import SecretsManagerClient
    from mypy_boto3_secretsmanager.type_defs import GetSecretValueResponseTypeDef
    from mypy_boto3_lambda import LambdaClient


def get_lambda_client() -> 'LambdaClient':
    """
    Get a boto3 lambda client
    """
    return boto3.client("lambda")


def get_secretsmanager_client() -> 'SecretManagerClient':
    """
    Get a boto3 secrets manager client.

    Returns:
        a boto3 secrets manager client
    """
    return boto3.client("secretsmanager")


def get_secret_value(secret_name: str) -> str:
    """
    Get the master API key from the string content of the given
    secret arn.

    Args:
        secret_name

    Returns:
        a trimmed string of the content of the secret
    """

    client = get_secretsmanager_client()

    secret_value = client.get_secret_value(SecretId=secret_name)

    # Decrypts secret using the associated KMS CMK.
    # Depending on whether the secret is a string or binary, one of these fields will be populated.
    if 'SecretString' in secret_value:
        return secret_value['SecretString']
    else:
        return b64decode(secret_value['SecretBinary']).decode()


def get_current_jwt_token() -> str:
    """
    Get the current JWT Token from AWS SecretsManager
    """
    return get_secret_value(environ['PIERIANDX_JWT_KEYNAME'])


def get_email_password_institution() -> Tuple[str, str, str]:
    """
    Get the email password from AWS SecretsManager
    """
    secret_obj = json.loads(get_secret_value(environ['PIERIANDX_API_KEYNAME']))

    return secret_obj['email'], secret_obj['password'], secret_obj['institution']


def check_rotation_state(secret_name: str, tok: str) -> bool:
    """
    Throws an exception if any part of our rotation state is incorrect.

    Return true if the state is such that there is nothing to do for this rotation - and if
    so we should return *from the caller* without doing any more secret processing.

    Args:
        secret_name:
        tok:

    Returns:
        true if the rotation state is so good we can literally return, false otherwise if we need
        to keep going
    """

    client = get_secretsmanager_client()

    metadata = client.describe_secret(SecretId=secret_name)

    if not metadata["RotationEnabled"]:
        raise ValueError(f"Secret {secret_name} is not enabled for rotation")

    versions = metadata["VersionIdsToStages"]

    if tok not in versions:
        raise ValueError(
            f"Secret version {tok} has no stage for rotation of secret {secret_name}"
        )

    if "AWSCURRENT" in versions[tok]:
        # our state is such that we don't need to do any more - we can return from the rotator entirely
        return True
    elif "AWSPENDING" not in versions[tok]:
        raise ValueError(
            f"Secret version ${tok} not set as AWSPENDING for rotation of secret {secret_name}"
        )

    # this is not bad - we've not encountered an error - it just means that we still should
    # do secrets step processing
    return False


def do_create_secret(
    arn: str,
    tok: str,
    access_token: str
) -> None:
    """
    Do the official create stage of a Secret rotation involving the logic for
    creating a secret and the safely saving it into the secret as pending.

    On rotation restart, if there is already a pending secret then the create stage is
    skipped.

    Args:
        arn: the secret arn
        tok: the client token for this particular rotation
        access_token: the access token to save
    """
    client = get_secretsmanager_client()

    try:
        # if get_secret_value works then we have a value and we should *not* create
        client.get_secret_value(SecretId=arn, VersionId=tok, VersionStage="AWSPENDING")

        # all we need to do is *not* doing anything - and the rotation machinery
        # will move on to the next stage
        return
    except Exception as e:
        # there was no secret value - so on to the creation code
        pass

    client.put_secret_value(
        SecretId=arn,
        ClientRequestToken=tok,
        SecretString=access_token,
        VersionStages=["AWSPENDING"],
    )


def do_finish_secret(arn: str, tok: str) -> None:
    """
    Do the official final stage of Secret rotation involving
    idempotently committing the new secret to current.

    Args:
        client: the boto3 secret manager client
        arn: the secret arn
        tok: the client token for this particular rotation
    """
    client = get_secretsmanager_client()

    metadata = client.describe_secret(SecretId=arn)

    current_version = None

    for version in metadata["VersionIdsToStages"]:
        if "AWSCURRENT" in metadata["VersionIdsToStages"][version]:
            # the correct version is already marked as current, return
            if version == tok:
                return
            current_version = version
            break

    client.update_secret_version_stage(
        SecretId=arn,
        VersionStage="AWSCURRENT",
        MoveToVersionId=tok,
        RemoveFromVersionId=current_version,
    )


def initiate_jwt_secret_rotation():
    """
    Initiate the secrets rotation
    """

    client = get_secretsmanager_client()

    secret_name = environ['PIERIANDX_JWT_KEYNAME']

    response = client.rotate_secret(
        SecretId=secret_name
    )

