import json
import logging
import re
from datetime import datetime, timedelta

import jwt
import requests
from jwt import algorithms as jwt_algo
from jwt import PyJWKClient

from jwt_helper import verify_jwt_structure, get_verified_jwt_claims

logger = logging.getLogger(__name__)

GA4GH_PASSPORT_V1 = "ga4gh_passport_v1"
GA4GH_VISA_V1 = "ga4gh_visa_v1"

ALLOWED_AUDIENCE = [
    "htsget.dev.umccr.org",
    "htsget.umccr.org",
]

TRUSTED_BROKERS = {
    'https://asha.sandbox.genovic.org.au': {
        'well_known': "/.well-known/openid-configuration",
        'alg': "RS256",
        'token_age_seconds': 3600,
    },
    'https://issuer1.sandbox.genovic.org.au': {
        'well_known': "/.well-known/openid-configuration",
        'alg': "RS256",
        'token_age_seconds': 3600,
    },
    'https://issuer2.sandbox.genovic.org.au': {
        'well_known': "/.well-known/openid-configuration",
        'alg': "RS256",
        'token_age_seconds': 3600,
    },
}


def test_passport_jwt(encoded_jwt: str) -> bool:
    # simple test right at the start to ensure that the token is at least basically structured like a JWT
    verify_jwt_structure(encoded_jwt)

    claims = get_verified_jwt_claims(encoded_jwt, ["https://umccr.ninja"], "foo")

    print(claims)

    is_authorized = False

    if GA4GH_PASSPORT_V1 in claims.keys():
        # client provided PASSPORT token
        encoded_visas = claims[GA4GH_PASSPORT_V1]
        for encoded_visa in encoded_visas:  # search appropriate visa in a passport, use the first found
            verify_jwt_structure(encoded_visa)
            visa_claims = get_verified_jwt_claims(encoded_visa)
            if perform_visa_check(visa_claims):
                is_authorized = True
                break

    elif GA4GH_VISA_V1 in claims.keys():
        # client provided VISA token
        is_authorized = perform_visa_check(claims)

    return is_authorized

def raise_error(message: dict):
    logger.error(json.dumps(message))
    raise ValueError(message.get('message', "Unexpected error occurred"))


def perform_visa_check(claims) -> bool:
    """
    TODO access decision making i.e.., what define ACL access rule on which dataset?
      we are mocking at the mo; i.e., ControlledAccessGrants on https://umccr.org/datasets/710
      we need DAC Portal and PASSPORT/VISA (data access) application process on this
      typically
       - data owner/holder shall able to publish/register their dataset in this DAC Portal
       - researcher shall able to apply VISA there
       - then, data owner/holder (such as us) who is running htsget data service can go DAC Portal and
         register dataset (bunch of DRS IDs?) there and denote them required VISA TYPE (like ControlledAccessGrants)
    """
    visa = claims[GA4GH_VISA_V1]

    visa_type = visa['type']
    visa_asserted = visa['asserted']
    visa_value = visa['value']
    visa_source = visa['source']
    visa_by: str = visa.get('by', "null")

    return visa_type == "ControlledAccessGrants" and "https://umccr.org/datasets/710" in visa_value


