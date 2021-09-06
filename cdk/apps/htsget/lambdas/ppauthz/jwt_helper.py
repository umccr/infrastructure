import logging
from typing import Any, List

import jwt

from oidc_helper import get_oidc_configuration

logger = logging.getLogger(__name__)


def verify_jwt_structure(encoded_jwt: str) -> None:
    """
    Check that JWT structure has 3 sections: header, payload, signature
    and raise an exception if this is not true.

    Args:
        encoded_jwt:

    Returns:

    """
    if len(encoded_jwt.split(".")) != 3:
        raise Exception("Bearer token was not a valid JWT")


def get_verified_jwt_claims(
    encoded_jwt: str, trusted_issuers: List[str], audience: str, test_mode: bool = False
) -> Any:
    """
    Parse a base 64 encoded JWT and verify its content - then return the content decoded.

    Args:
        encoded_jwt: the base 64 encoded JWT
        trusted_issuers: a list of issuer strings that the issuer MUST match exactly
        audience: the required audience of the JWT
        test_mode: if true, skips time based token expiry checks - default to false

    Returns:
        the decoded and verified JWT payload
    """
    # these we allow as input in an unverified state - but only in the first instance
    unverified_header = jwt.get_unverified_header(encoded_jwt)
    unverified_payload = jwt.decode(encoded_jwt, options={"verify_signature": False})

    kid = unverified_header["kid"]
    iss = unverified_payload["iss"]

    if iss not in trusted_issuers:
        raise Exception(f"Not proceeding processing untrusted issuer '{iss}'")

    oidc_config = get_oidc_configuration(iss)

    signing_key = oidc_config.get_signing_key(kid)

    data = jwt.decode(
        encoded_jwt,
        signing_key.key,
        algorithms=oidc_config.algorithms,
        audience=audience,
        options={"verify_exp": not test_mode},
    )

    return data
