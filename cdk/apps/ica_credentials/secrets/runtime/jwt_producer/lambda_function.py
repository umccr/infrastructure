import boto3
import json
import os
import urllib3
import traceback


def main(ev, _):
    """
    Uses a master API key secret to generate new JWTs.
    """
    arn = ev["SecretId"]
    tok = ev["ClientRequestToken"]
    step = ev["Step"]

    print(f"Starting step '{step}' of Secret Rotation for secret {arn}")

    master_arn = os.environ["MASTER_ARN"]
    ica_base_url = os.environ["ICA_BASE_URL"]

    sm_client = boto3.client("secretsmanager")

    try:
        master_resp = sm_client.get_secret_value(SecretId=master_arn)

        master_val = master_resp["SecretString"]

    except Exception as e:
        print("Error fetching master secret")
        print(traceback.format_exc())
        raise e

    # make sure the version is staged correctly
    try:
        metadata = sm_client.describe_secret(SecretId=arn)

        if not metadata["RotationEnabled"]:
            raise ValueError(f"Secret {arn} is not enabled for rotation")

        versions = metadata["VersionIdsToStages"]

        if tok not in versions:
            raise ValueError(
                f"Secret version {tok} has no stage for rotation of secret {arn}"
            )

        if "AWSCURRENT" in versions[tok]:
            return
        elif "AWSPENDING" not in versions[tok]:
            raise ValueError(
                f"Secret version ${tok} not set as AWSPENDING for rotation of secret {arn}"
            )
    except Exception as e:
        print("Error with state of secrets steps")
        print(traceback.format_exc())
        raise e

    try:
        if step == "createSecret":
            create_secret(sm_client, master_val, ica_base_url, arn, tok)
        elif step == "setSecret":
            pass
            # set_secret(service_client, arn, token)
        elif step == "testSecret":
            pass
        elif step == "finishSecret":
            finish_secret(sm_client, arn, tok)
        else:
            raise ValueError("Invalid step parameter")
    except Exception as e:
        print(f"Error with step '{step}'")
        print(traceback.format_exc())
        raise e


def create_secret(
    client, master_val, ica_base_url, arn, tok
):
    """
    Create a new JWT via the ICA APIs
    """
    try:
        # if get works here then we have a value and we should *not* create
        client.get_secret_value(SecretId=arn, VersionId=tok, VersionStage="AWSPENDING")
    except:
        http = urllib3.PoolManager()

        r = http.request(
            "POST",
            f"{ica_base_url}/v1/tokens",
            headers={
                "Accept": "application/json",
                "X-API-Key": master_val,
            },
            body=None,
        )

        if r.status == 201:
            jwt = json.loads(r.data.decode("utf-8"))["access_token"]

            client.put_secret_value(
                SecretId=arn,
                ClientRequestToken=tok,
                SecretString=jwt,
                VersionStages=["AWSPENDING"],
            )
            print(
                f"Successfully put secret for ARN {arn} and version {tok}"
            )
        else:
            raise Exception(f"ICA token exchange response {r.status}")


def finish_secret(client, arn, tok):
    """
    Safely promote the just created version of the secret to be the final version.
    """
    metadata = client.describe_secret(SecretId=arn)
    current_version = None
    for version in metadata["VersionIdsToStages"]:
        if "AWSCURRENT" in metadata["VersionIdsToStages"][version]:
            # The correct version is already marked as current, return
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

    print(
        f"Successfully finished secret for ARN {arn} and version {tok}"
    )
