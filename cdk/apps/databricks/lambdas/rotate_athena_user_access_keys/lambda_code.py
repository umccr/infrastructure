#!/usr/bin/env python3

"""
Rotate user access keys (weekly rotation)

Steps are
1: List existing access keys.
2: If both access keys have been created in the last two weeks, then don't delete
3: Remove any access keys older than two weeks
4: Create new access key
5: Update Databricks secrets with new access key
"""

# Standard imports
import os
import sys
from copy import deepcopy
from subprocess import run
from time import sleep
from typing import List
import logging
from datetime import datetime, timedelta
from boto3 import Session

# Boto3 Clients
from mypy_boto3_secretsmanager.client import SecretsManagerClient
from mypy_boto3_iam.client import IAMClient
from mypy_boto3_ssm.client import SSMClient

# Boto3 type hinting
from mypy_boto3_secretsmanager.type_defs import GetSecretValueResponseTypeDef
from mypy_boto3_iam.type_defs import (
    AccessKeyMetadataTypeDef, ListAccessKeysResponseTypeDef,
    AccessKeyTypeDef
)
from mypy_boto3_ssm.type_defs import ParameterTypeDef

# Globals
DATABRICKS_SCOPE = "athena"
DATABRICKS_SECRET_ACCESS_KEY_ID_NAME = "service_user_access_key_id"
DATABRICKS_SECRET_SECRET_ACCESS_KEY_NAME = "service_user_secret_access_key"
DATABRICKS_ROLE_ARN_NAME = "service_user_role"
MAX_KEYS = 2


def get_iam_client() -> IAMClient:
    return Session().client("iam")


def get_secrets_manager_client() -> SecretsManagerClient:
    return Session().client("secretsmanager")


def get_ssm_client() -> SSMClient:
    return Session().client("ssm")


# IAM Functions
def list_access_keys(user_name: str) -> List[AccessKeyMetadataTypeDef]:
    """
    List of dict with the following keys
    UserName
    AccessKeyId
    Status
    CreateDate: dtObject
    """

    response: ListAccessKeysResponseTypeDef = get_iam_client().list_access_keys(
        UserName=user_name
    )

    return response.get("AccessKeyMetadata")


def delete_user_key(user_name: str, access_key_id: str):
    """
    Delete a user access key
    :param user_name:
    :param access_key_id:
    :return:
    """
    iam_client = get_iam_client()

    iam_client.delete_access_key(
        UserName=user_name,
        AccessKeyId=access_key_id
    )


def create_new_access_key(user_name: str) -> AccessKeyTypeDef:
    """
    Create an access key for the user
    :param user_name:
    :return:
    """
    iam_client = get_iam_client()

    return iam_client.create_access_key(
        UserName=user_name
    ).get("AccessKey")


# Secrets manager functions
def get_secret_value_from_aws_secrets_manager(secrets_arn: str) -> str:
    secrets_client = get_secrets_manager_client()

    secret_obj: GetSecretValueResponseTypeDef = secrets_client.get_secret_value(
        SecretId=str(secrets_arn)
    )

    return secret_obj.get("SecretString")


def get_value_from_aws_ssm_parameter(ssm_parameter_name: str) -> str:
    """
    Get an ssm value
    :param ssm_parameter_name:
    :return:
    """
    ssm_client: SSMClient = get_ssm_client()

    ssm_parameter: ParameterTypeDef = ssm_client.get_parameter(Name=ssm_parameter_name).get("Parameter")

    return ssm_parameter.get("Value")


def add_databricks_secret_scope(scope: str, secret_name: str, secret_value: str, databricks_access_token: str, databricks_host: str):
    """
    Add the databricks secret scope
    :param scope:
    :param secret_name:
    :param secret_value:
    :param databricks_access_token:
    :param databricks_host: å
    :return:
    """

    # Set env
    env = deepcopy(os.environ)
    env["DATABRICKS_TOKEN"] = databricks_access_token
    env["DATABRICKS_HOST"] = databricks_host
    env["DATABRICKS_AUTH_TYPE"] = "pat"

    # Set CLI command
    databricks_set_access_token_command = [
        "databricks", "secrets",
        "put-secret", scope,
        secret_name,
        "--string-value", secret_value
    ]

    databricks_access_token_proc = run(
        databricks_set_access_token_command,
        env=env,
        capture_output=True
    )

    if not databricks_access_token_proc.returncode == 0:
        logging.error("Error! Could not sync secrets to Databricks")
        logging.error(f"Stdout is {databricks_access_token_proc.stdout.decode()}")
        logging.error(f"Stderr is {databricks_access_token_proc.stderr.decode()}")
        raise ChildProcessError


def handler(event, context):
    """
    List, and remove old access keys,

    ATHENA_USER_NAME
    DATABRICKS_SERVICE_USER_TOKEN_SECRETS_MANAGER_ARN
    DATABRICKS_HOST_SSM_PARAMETER_NAME
    DATABRICKS_ATHENA_ROLE_ARN
    """
    # Get athena username from event
    user_name = event.get("ATHENA_USER_NAME", None)
    secrets_manager_arn = event.get("DATABRICKS_SERVICE_USER_TOKEN_SECRETS_MANAGER_ARN", None)
    databricks_host_ssm_parameter_name = event.get("DATABRICKS_HOST_SSM_PARAMETER_NAME", None)
    databricks_role_arn = event.get("DATABRICKS_ATHENA_ROLE_ARN", None)

    if user_name is None:
        logging.error("Could not get user name from env var ATHENA_USER_NAME")
        raise EnvironmentError

    if secrets_manager_arn is None:
        logging.error(f"Could not get the secrets manager path needed to get databricks service token from event")
        raise EnvironmentError

    if databricks_host_ssm_parameter_name is None:
        logging.error("Could not get the databricks host ssm")
        raise EnvironmentError

    if databricks_role_arn is None:
        logging.error("Could not get the role to assume arn")
        raise EnvironmentError

    # List existing access keys, remove any access keys older than two weeks
    keys_to_delete: List[AccessKeyMetadataTypeDef] = []
    current_access_keys = list_access_keys(user_name=user_name)
    for key_obj in keys_to_delete:
        # Access key creation date
        access_key_creation_date: datetime = key_obj.get("CreateDate")
        if (access_key_creation_date + timedelta(weeks=2)) < datetime.utcnow():
            keys_to_delete.append(key_obj)

    # Check if we have any keys to delete
    if len(keys_to_delete) == 0 and not len(current_access_keys) < MAX_KEYS:
        logging.info("No more room for any more keys and no keys have expired, exiting")
        sys.exit(0)
    
    # Delete keys 
    for index, key_obj in enumerate(keys_to_delete.copy()):
        # Get access key
        access_key_id = str(key_obj.get("AccessKeyId"))

        # Delete the user key
        delete_user_key(
            user_name=user_name,
            access_key_id=access_key_id
        )

        # Pop the access key from the keys to delete index
        keys_to_delete.pop(index)

    # Wait for AWS to sync
    sleep(5)

    # Re-collect the current access keys
    current_access_keys = list_access_keys(user_name=user_name)

    # Check if we can add another access key
    if len(current_access_keys) < MAX_KEYS:
        logging.info("Room to add in another key")

    # Create a new aws access key
    new_access_key = create_new_access_key(user_name=user_name)

    # Update databricks secrets with new access key id
    add_databricks_secret_scope(
        scope=DATABRICKS_SCOPE,
        secret_name=DATABRICKS_SECRET_ACCESS_KEY_ID_NAME,
        secret_value=new_access_key.get("AccessKeyId"),
        databricks_access_token=get_secret_value_from_aws_secrets_manager(secrets_manager_arn),
        databricks_host=get_value_from_aws_ssm_parameter(databricks_host_ssm_parameter_name)
    )

    # Update databricks secrets with new secret access key
    add_databricks_secret_scope(
        scope=DATABRICKS_SCOPE,
        secret_name=DATABRICKS_SECRET_SECRET_ACCESS_KEY_NAME,
        secret_value=new_access_key.get("SecretAccessKey"),
        databricks_access_token=get_secret_value_from_aws_secrets_manager(secrets_manager_arn),
        databricks_host=get_value_from_aws_ssm_parameter(databricks_host_ssm_parameter_name)
    )

    # Add role arn that is to be assumed by Databricks, doesn't necessarily need to be secret but this way
    # everything is all in one place
    add_databricks_secret_scope(
        scope=DATABRICKS_SCOPE,
        secret_name=DATABRICKS_ROLE_ARN_NAME,
        secret_value=databricks_role_arn,
        databricks_access_token=get_secret_value_from_aws_secrets_manager(secrets_manager_arn),
        databricks_host=get_value_from_aws_ssm_parameter(databricks_host_ssm_parameter_name)
    )
