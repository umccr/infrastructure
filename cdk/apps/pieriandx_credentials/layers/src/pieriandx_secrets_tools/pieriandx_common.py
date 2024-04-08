#!/usr/bin/env python3

"""

"""

import requests
import typing
from typing import Dict
import jwt
from datetime import datetime

from jwt import DecodeError

EXPIRY_BUFFER = 60  # 1 minute


# Twv2 platforms
def credentials_to_jwt(pieriandx_base_url: str, email: str, password: str, institution: str) -> str:
    """
    Given a pieriandx URL, username and password, exchange these for a JWT token.
    """

    # Request headers
    headers = {
        'Accept': 'application/json',
        'X-Auth-Email': email,
        'X-Auth-Key': password,
        'X-Auth-Institution': institution,
    }

    # Get response
    response = requests.get(
        f"{pieriandx_base_url}/v2.0.0/login",
        headers=headers
    )

    # Check response
    if not response.ok:
        raise Exception(f"Failed to get JWT token from PierianDX: {response.text}")

    if "X-Auth-Token" not in response.headers:
        raise Exception(f"Failed to get JWT token from PierianDX: {response.text}")

    return response.headers["X-Auth-Token"]


def decode_jwt(jwt_string: str) -> Dict:
    return jwt.decode(
        jwt_string,
        algorithms=["HS256"],
        options={"verify_signature": False}
    )


def jwt_is_valid(jwt_string: str) -> bool:
    try:
        decode_jwt(jwt_string)
        timestamp_exp = decode_jwt(jwt_string).get("exp")

        # If timestamp will expire in less than one minute's time, return False
        if int(timestamp_exp) + EXPIRY_BUFFER < int(datetime.now().timestamp()):
            return False
        else:
            return True
    except DecodeError as e:
        return False


