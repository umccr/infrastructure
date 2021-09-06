import json
from typing import Any
from urllib.parse import urlencode

import urllib3


def api_key_to_jwt_for_project(ica_base_url: str, api_key: str, cid: str) -> str:
    """
    Using the API key, exchanges it for a JWT that will have the API keys user permission
    *only* in the passed in project context.

    Args:
        ica_base_url: the base URL for ICA
        api_key: the API key for a user
        cid: the project id

    Returns:
        a JWT access token

    Notes:
        uses urllib3 rather than a more featured library as this allows us to
        avoid a more complex lambda build step (urllib3 is built into lambda base image).
    """
    http = urllib3.PoolManager()

    # restrict to project (cid) level
    encoded_params = urlencode({'cid': cid})

    url = f"{ica_base_url}/v1/tokens?{encoded_params}"

    r = http.request(
        "POST",
        url,
        headers={
            "Accept": "application/json",
            "X-API-Key": api_key,
        },
        body=None,
    )

    if r.status == 201:
        body = r.data.decode("utf-8")
        body_as_json = json.loads(body)

        if "access_token" in body_as_json:
            # success
            return body_as_json["access_token"]

    # fall through to failure
    print(f"Failed ICA token exchange POST to '{url}'")
    print(r.status)
    print(r.headers)
    print(r.data)

    raise Exception(f"ICA token exchange failed - see CloudWatch logs")
