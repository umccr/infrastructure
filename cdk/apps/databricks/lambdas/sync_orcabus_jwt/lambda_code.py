#!/usr/bin/env python3

"""
Sync Orcabus Token JWT to DataBricks

Copies over Portal Orcabus JWT to DataBricks

This allows databricks to access dracarys

We will soon make this a read-only JWT token
"""

# Import
import logging
import os
from copy import deepcopy
from subprocess import run
from boto3 import Session

# Boto 3 Type Hinting
from mypy_boto3_secretsmanager.client import SecretsManagerClient
from mypy_boto3_secretsmanager.type_defs import GetSecretValueResponseTypeDef
from mypy_boto3_ssm import SSMClient
from mypy_boto3_ssm.type_defs import ParameterTypeDef

# Globals
DATABRICKS_SCOPE = "orcabus"
DATABRICKS_SECRET_NAME = "orcabus_jwt"


def get_secrets_manager_client() -> SecretsManagerClient:
    return Session().client("secretsmanager")


def get_ssm_client() -> SSMClient:
    return Session().client("ssm")


def get_secret(secret_arn: str) -> str:
    """
    Get secret from secrets manager
    :param secret_arn:
    :return:
    """

    # Create secrets manager client
    client = get_secrets_manager_client()

    # Get secret
    secret: GetSecretValueResponseTypeDef = client.get_secret_value(SecretId=secret_arn)

    return secret.get("SecretString")


def get_value_from_aws_ssm_parameter(ssm_parameter_name: str) -> str:
    """
    Get an ssm value
    :param ssm_parameter_name:
    :return:
    """
    ssm_client: SSMClient = get_ssm_client()

    ssm_parameter: ParameterTypeDef = ssm_client.get_parameter(Name=ssm_parameter_name).get("Parameter")

    return ssm_parameter.get("Value")


def handler(event, context):
    """
    Collect Orcabus Access token value
    Run DataBricks CLI to update secret

    Event contains the following parameters

    Orcabus Access Token Secrets Manager ARN
    ORCABUS_ACCESS_TOKEN_SECRET_ARN =
    """

    # Get path from environment
    orcabus_token_secret_arn = event.get("ORCABUS_TOKEN_SECRETS_MANAGER_ARN", None)
    databricks_access_token_arn = event.get("DATABRICKS_SERVICE_USER_TOKEN_SECRETS_MANAGER_ARN", None)
    databricks_host_ssm_parameter_name = event.get("DATABRICKS_HOST_SSM_PARAMETER_NAME", None)

    # Check access token
    if orcabus_token_secret_arn is None:
        logging.error("Could not get env var ORCABUS_TOKEN_SECRETS_MANAGER_ARN")
        raise EnvironmentError

    if databricks_access_token_arn is None:
        logging.error(f"Could not get the secrets manager path needed to get databricks service token from event")
        raise EnvironmentError

    if databricks_host_ssm_parameter_name is None:
        logging.error("Could not get the databricks host ssm")
        raise EnvironmentError

    # Get access token from secrets manager
    orcabus_token: str = get_secret(orcabus_token_secret_arn)

    # Set env
    env = deepcopy(os.environ)
    env["DATABRICKS_TOKEN"] = get_secret(databricks_access_token_arn)
    env["DATABRICKS_HOST"] = get_value_from_aws_ssm_parameter(databricks_host_ssm_parameter_name)
    env["DATABRICKS_AUTH_TYPE"] = "pat"

    # Databricks secret command
    databricks_secrets_command = [
        "databricks", "secrets",
        "put-secret", DATABRICKS_SCOPE,
        DATABRICKS_SECRET_NAME,
        "--string-value", orcabus_token
    ]

    # Run databricks CLI to update scope
    databricks_secrets_proc = run(
        databricks_secrets_command,
        capture_output=True,
        env=env
    )

    # Check return code
    if databricks_secrets_proc.returncode != 0:
        logging.error("Could not update databricks secret")
        logging.error(f"Stdout was {databricks_secrets_proc.stdout.decode()}")
        logging.error(f"Stderr was {databricks_secrets_proc.stderr.decode()}")
        raise ChildProcessError

    # Return
