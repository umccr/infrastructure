#!/usr/bin/env python3

from typing import Any, Optional, Dict
from pieriandx_secrets_tools.secret_manager_common import (
    get_current_jwt_token, initiate_jwt_secret_rotation, get_jwt_token_status
)

from pieriandx_secrets_tools.pieriandx_common import jwt_is_valid
import time


def main(ev: Any, _: Any) -> Optional[Dict]:
    """
    Uses a master API key secret to generate new JWTs. In order that we can use a single
    lambda, there are various environment variables that parametrise how the lambda works.

    Required envs
    PIERIANDX_JWT_KEYNAME  the JWT Key name of a secret from which we can get an PIERIANDX JWT Token
    """

    # Get the secret status (check if 'AWS_PENDING' or 'AWS_CURRENT')
    if not get_jwt_token_status():
        # In rotating state
        return None

    # Get the secret value
    access_token = get_current_jwt_token()

    if not jwt_is_valid(access_token):
        # Rotate the secret
        initiate_jwt_secret_rotation()
        return None

    return {"auth_token": access_token}


if __name__ == "__main__":
    main({}, None)
