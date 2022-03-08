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


def main(ev: Any, _: Any) -> Any:
    """
    Uses a master API key secret to generate new JWTs. In order that we can use a single
    lambda, there are various environment variables that parametrise how the lambda works.

    Required
    MASTER_ARN  the arn of a secret from which we can get an ICA API key
    ICA_BASE_URL  the url of the ICA endpoint

    Params
    PROJECT_ID  or  PROJECT_IDS   the projects to ask for in the JWT - this alters the format of the
                                  resulting Secret (either straight JWT *or* dictionary)
    """
    arn = ev["SecretId"]
    tok = ev["ClientRequestToken"]
    step = ev["Step"]

    print(f"Starting step '{step}' of secret '{arn}' and version '{tok}'")

    master_arn = os.environ["MASTER_ARN"]

    if not master_arn:
        raise Exception("MASTER_ARN must be specified in the JWT producer")

    ica_base_url = os.environ["ICA_BASE_URL"]

    if not ica_base_url:
        raise Exception("ICA_BASE_URL must be specified in the JWT producer")

    # Initialise v1 vars
    project_id = None
    project_ids = None

    if is_ica_v2_platform := os.environ["ICA_PLATFORM_VERSION"] == "V2":
        from ica_common import api_key_to_jwt_for_project_v2 as api_key_to_jwt_for_project
    else:  # V1
        # We import the api_key_to_jwt_for_project method for v1
        from ica_common import api_key_to_jwt_for_project_v1 as api_key_to_jwt_for_project

        # we operate in two basic modes - in one we have a single project id and generate a single JWT for it
        # when given multiple ids however, ICA doesn't allow a combined JWT - so instead we generate a dictionary
        # of JWTS one per project - and put that dictionary into the secret
        if "PROJECT_ID" in os.environ:
            project_id = os.environ["PROJECT_ID"]
        else:
            project_id = None

        if "PROJECT_IDS" in os.environ:
            project_ids = os.environ["PROJECT_IDS"].split()
        else:
            project_ids = []

        if project_id and project_ids:
            raise Exception(
                "Only one of PROJECT_ID or PROJECT_IDS can be specified in the JWT producer"
            )

        if not project_id and not project_ids:
            raise Exception(
                "One of PROJECT_ID or PROJECT_IDS must be specified in the JWT producer"
            )

    sm_client = boto3.client("secretsmanager")

    master_val = get_master_api_key(sm_client, master_arn)

    # the rotation state checker will also let us know if we should skip processing entirely
    if check_rotation_state(sm_client, arn, tok):
        print(
            f"Successfully skipped step '{step}' of secret '{arn}' and version '{tok}' because of state information"
        )
        return

    if step == "createSecret":

        def exchange_multi() -> str:
            result = {}
            for p in project_ids:
                result[p] = api_key_to_jwt_for_project(ica_base_url, master_val, p)
            return json.dumps(result)

        def exchange_single() -> str:
            return api_key_to_jwt_for_project(ica_base_url, master_val, project_id)

        do_create_secret(
            sm_client, arn, tok,
            exchange_single if is_ica_v2_platform or project_id is not None
            else exchange_multi
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
