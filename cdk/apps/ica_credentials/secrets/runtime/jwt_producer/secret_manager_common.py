import traceback
from typing import Any, Callable


def get_master_api_key(client: Any, master_arn) -> str:
    """
    Get the master API key from the string content of the given
    secret arn.

    Args:
        client:
        master_arn:

    Returns:
        a trimmed string of the content of the secret
    """
    try:
        master_resp = client.get_secret_value(SecretId=master_arn)

        if "SecretString" in master_resp:
            return str(master_resp["SecretString"]).strip()

        raise Exception(f"No secret string in master key {master_arn}")

    except Exception as e:
        print("Error fetching master secret")
        print(traceback.format_exc())
        raise e


def check_rotation_state(client: Any, arn: str, tok: str) -> bool:
    """
    Throws an exception if any part of our rotation state is incorrect.

    Return true if the state is such that there is nothing to do for this rotation - and if
    so we should return *from the caller* without doing any more secret processing.

    Args:
        client:
        arn:
        tok:

    Returns:
        true if the rotation state is so good we can literally return, false otherwise if we need
        to keep going
    """
    metadata = client.describe_secret(SecretId=arn)

    if not metadata["RotationEnabled"]:
        raise ValueError(f"Secret {arn} is not enabled for rotation")

    versions = metadata["VersionIdsToStages"]

    if tok not in versions:
        raise ValueError(
            f"Secret version {tok} has no stage for rotation of secret {arn}"
        )

    if "AWSCURRENT" in versions[tok]:
        # our state is such that we don't need to do any more - we can return from the rotator entirely
        return True
    elif "AWSPENDING" not in versions[tok]:
        raise ValueError(
            f"Secret version ${tok} not set as AWSPENDING for rotation of secret {arn}"
        )

    # this is not bad - we've not encountered an error - it just means that we still should
    # do secrets step processing
    return False


def do_create_secret(
    client: Any, arn: str, tok: str, creator: Callable[[], str]
) -> None:
    """
    Do the official create stage of a Secret rotation involving the logic for
    creating a secret and the safely saving it into the secret as pending.

    On rotation restart, if there is already a pending secret then the create stage is
    skipped.

    Args:
        client: the boto3 secret manager client
        arn: the secret arn
        tok: the client token for this particular rotation
        creator: a creator function that should return the new string secret
    """
    try:
        # if get_secret_value works then we have a value and we should *not* create
        client.get_secret_value(SecretId=arn, VersionId=tok, VersionStage="AWSPENDING")

        # all we need to do is *not* doing anything - and the rotation machinery
        # will move on to the next stage
        return
    except Exception as e:
        # there was no secret value - so on to the creation code
        pass

    new_secret = creator()

    client.put_secret_value(
        SecretId=arn,
        ClientRequestToken=tok,
        SecretString=new_secret,
        VersionStages=["AWSPENDING"],
    )


def do_finish_secret(client: Any, arn: str, tok: str) -> None:
    """
    Do the official final stage of Secret rotation involving
    idempotently committing the new secret to current.

    Args:
        client: the boto3 secret manager client
        arn: the secret arn
        tok: the client token for this particular rotation
    """
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
