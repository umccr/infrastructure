#!/usr/bin/env python3

import os
from typing import Any

import boto3

from pieriandx_secrets_tools.secret_manager_common import (
    do_finish_secret,
    do_create_secret,
    check_rotation_state,
    get_email_password_institution
)

from pieriandx_secrets_tools.pieriandx_common import credentials_to_jwt


def main(ev: Any, _: Any) -> Any:
    """
    Uses a master API key secret to generate new JWTs. In order that we can use a single
    lambda, there are various environment variables that parametrise how the lambda works.

    Required
    API_KEY_AWS_SECRETS_MANAGER_ARN  the arn of a secret from which we can get an ICA API key
    ICA_BASE_URL  the url of the ICA endpoint

    Params
    PROJECT_ID  or  PROJECT_IDS   the projects to ask for in the JWT - this alters the format of the
                                  resulting Secret (either straight JWT *or* dictionary)
    """
    arn = ev["SecretId"]
    tok = ev["ClientRequestToken"]
    step = ev["Step"]

    print(f"Starting step '{step}' of secret '{arn}' and version '{tok}'")

    master_secret_name = os.environ["PIERIANDX_API_KEYNAME"]

    if not master_secret_name:
        raise Exception("API_KEY_AWS_SECRETS_MANAGER_ARN must be specified in the JWT producer")

    # Add PierianDx base url
    pieriandx_base_url = os.environ["PIERIANDX_BASE_URL"]

    if not pieriandx_base_url:
        raise Exception("PIERIANDX_BASE_URL must be specified in the JWT producer")

    # Get secrets manager client
    sm_client = boto3.client("secretsmanager")

    # Get master api key
    master_email, master_password, institution = get_email_password_institution()

    access_token = credentials_to_jwt(
        pieriandx_base_url=pieriandx_base_url,
        email=master_email,
        password=master_password,
        institution=institution
    )

    # the rotation state checker will also let us know if we should skip processing entirely
    if check_rotation_state(arn, tok):
        print(
            f"Successfully skipped step '{step}' of secret '{arn}' and version '{tok}' because of state information"
        )
        return

    if step == "createSecret":
        do_create_secret(
            arn=arn,
            tok=tok,
            access_token=access_token
        )

    elif step == "setSecret":
        pass
    elif step == "testSecret":
        pass
    elif step == "finishSecret":
        do_finish_secret(arn, tok)
    else:
        raise ValueError("Invalid step parameter")

    print(f"Successfully finished step '{step}' of secret '{arn}' and version '{tok}'")
