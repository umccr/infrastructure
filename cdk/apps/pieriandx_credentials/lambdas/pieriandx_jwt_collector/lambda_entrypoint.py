#!/usr/bin/env python3

from typing import Any, Optional
from pieriandx_secrets_tools.secret_manager_common import (
    get_current_jwt_token, initiate_jwt_secret_rotation
)

from pieriandx_secrets_tools.pieriandx_common import jwt_is_valid


def main(ev: Any, _: Any) -> Optional[str]:
    """
    Uses a master API key secret to generate new JWTs. In order that we can use a single
    lambda, there are various environment variables that parametrise how the lambda works.

    Required envs
    PIERIANDX_JWT_KEYNAME  the JWT Key name of a secret from which we can get an PIERIANDX JWT Token
    """

    # Get the secret value
    access_token = get_current_jwt_token()

    if not jwt_is_valid(access_token):
        # Rotate the secret
        initiate_jwt_secret_rotation()
        return None

    return access_token
