import re
from typing import Any


def extract_bearer_token(event: Any) -> str:
    """
    Extract authorization from AWS Lambda authorizer headers. See Payload format for version 2.0
    https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-lambda-authorizer.html

    Args:
        event: an API gateway *authorisation* lambda event

    Returns:
        the base 64 encoded JWT used as a bearer token
    """
    authz_header: str = event['headers']['authorization']

    if not re.search(r"^Bearer", authz_header, re.IGNORECASE):
        raise Exception("No Bearer found in authorization header")

    authz_header = re.sub(r"^Bearer", "", authz_header, flags=re.IGNORECASE).strip()

    return authz_header
