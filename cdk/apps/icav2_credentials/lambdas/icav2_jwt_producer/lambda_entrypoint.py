import json
import os
from time import sleep
from typing import Any

import boto3

from secret_manager_common import (
    get_master_api_key,
    do_finish_secret,
    do_create_secret,
    check_rotation_state,
)
from ica_common import api_key_to_jwt_for_project_v2


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

    master_arn = os.environ["API_KEY_AWS_SECRETS_MANAGER_ARN"]

    if not master_arn:
        raise Exception("API_KEY_AWS_SECRETS_MANAGER_ARN must be specified in the JWT producer")

    icav2_base_url = os.environ["ICAV2_BASE_URL"]

    if not icav2_base_url:
        raise Exception("ICAV2_BASE_URL must be specified in the JWT producer")

    # Get secrets manager client
    sm_client = boto3.client("secretsmanager")

    # Get master api key
    master_val = get_master_api_key(sm_client, master_arn)

    # Get token
    access_token = api_key_to_jwt_for_project_v2(
        ica_base_url=icav2_base_url,
        api_key=master_val
    )

    # the rotation state checker will also let us know if we should skip processing entirely
    if check_rotation_state(sm_client, arn, tok):
        print(
            f"Successfully skipped step '{step}' of secret '{arn}' and version '{tok}' because of state information"
        )
        return

    if step == "createSecret":
        do_create_secret(
            client=sm_client,
            arn=arn,
            tok=tok,
            access_token=access_token
        )

        # JWTs are not immediately useful due to ICA clock skew and nbf claims
        # https://github.com/umccr-illumina/stratus/issues/151
        # So we delay here which delays the availability of this new JWT to the outside world
        sleep(30)

    elif step == "setSecret":
        pass
    elif step == "testSecret":
        pass
    elif step == "finishSecret":
        do_finish_secret(sm_client, arn, tok)
    else:
        raise ValueError("Invalid step parameter")

    print(f"Successfully finished step '{step}' of secret '{arn}' and version '{tok}'")
