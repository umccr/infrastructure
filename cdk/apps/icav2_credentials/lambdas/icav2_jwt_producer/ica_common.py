import json
from typing import Optional
from urllib.parse import urlencode

import urllib3


# Twv2 platforms
def api_key_to_jwt_for_project_v2(ica_base_url: str, api_key: str) -> str:
    return api_key_to_jwt_for_project(url=f"{ica_base_url}/api/tokens",
                                      accept_value="application/vnd.illumina.v3+json",
                                      encoded_params=None,
                                      api_key=api_key,
                                      output_attribute="token")


def api_key_to_jwt_for_project(url: str, accept_value: str, encoded_params: Optional[str], api_key: str, output_attribute: str) -> str:
    """
    Using the API key, exchanges it for a JWT that will have the API keys user permission
    *only* in the passed in project context.

    Args:
        ica_base_url: the base URL for ICA
        accept_value: Either 'application/json' or 'application/vnd.illumina.v3+json' for v1 or v2 respectfully
        api_key: the API key for a user
        encoded_params: For v1 projects, is a project ID required? Or a tenant required for v2?

    Returns:
        a JWT access token

    Notes:
        uses urllib3 rather than a more featured library as this allows us to
        avoid a more complex lambda build step (urllib3 is built into lambda base image).
    """
    http = urllib3.PoolManager()

    if encoded_params is not None:
        url = f"{url}?{encoded_params}"

    r = http.request(
        "POST",
        url,
        headers={
            "Accept": accept_value,
            "X-API-Key": api_key,
        },
        body=None,
    )

    if r.status == 200:
        body = r.data.decode("utf-8")
        body_as_json = json.loads(body)

        if output_attribute in body_as_json:
            # success
            return body_as_json[output_attribute]

    # fall through to failure
    print(f"Failed ICAv2 token exchange POST to '{url}'")
    print(r.status)
    print(r.headers)

    raise Exception(f"ICAv2 token exchange failed - see CloudWatch logs")
