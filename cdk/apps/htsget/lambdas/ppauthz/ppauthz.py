import json
import logging
import re
from datetime import datetime, timedelta

import jwt
import requests
from jwt import algorithms as jwt_algo

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

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


def raise_error(message: dict):
    logger.error(json.dumps(message))
    raise ValueError(message.get('message', "Unexpected error occurred"))


def extract_token(event) -> str:
    """
    Extract authorization from AWS Lambda authorizer headers. See Payload format for version 2.0
    https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-lambda-authorizer.html

    :param event:
    :return:
    """
    authz_header: str = event['headers']['authorization']

    if not re.search("^Bearer", authz_header, re.IGNORECASE):
        raise_error({'message': "No Bearer found in authorization header"})

    authz_header = re.sub("^Bearer", "", authz_header, flags=re.IGNORECASE).strip()

    return authz_header


def verify_jwt_structure(encoded_jwt) -> bool:
    """
    Check that JWT structure has 3 sections: header, payload, signature

    :param encoded_jwt:
    :return:
    """
    if len(encoded_jwt.split(".")) != 3:
        raise_error({'message': "Not a valid JWT"})
    return True


def get_verified_jwt_claims(encoded_jwt):
    unverified_header = jwt.get_unverified_header(encoded_jwt)
    unverified_payload = jwt.decode(encoded_jwt, options={'verify_signature': False})

    kid = unverified_header['kid']
    iss = unverified_payload['iss']
    exp = unverified_payload['exp']
    iat = unverified_payload['iat']
    aud = unverified_payload.get('aud')

    if iss not in TRUSTED_BROKERS.keys():
        raise_error({'message': f"Found untrusted broker: {iss}"})

    now_dt = datetime.now()

    exp_dt = datetime.fromtimestamp(exp)
    if now_dt > exp_dt:
        raise_error({'message': f"Token has expired since {exp_dt.astimezone().isoformat()}"})

    iat_dt = datetime.fromtimestamp(iat)
    token_age = TRUSTED_BROKERS[iss]['token_age_seconds']
    if timedelta.total_seconds(now_dt - iat_dt) > token_age:
        raise_error({'message': f"Token is too old. It has issued since {iat_dt.astimezone().isoformat()}. "
                                f"Allowed token age is {token_age} seconds."})

    if aud is not None and aud not in ALLOWED_AUDIENCE:
        raise_error({'message': f"Found unrecognised audience claim: {aud}"})

    well_known_config = requests.get(iss + TRUSTED_BROKERS[iss]['well_known']).json()
    jwks_uri = well_known_config['jwks_uri']
    jwks = requests.get(jwks_uri).json()

    public_keys = {}
    for jwk in jwks['keys']:
        _kid: str = jwk['kid']
        _alg: str = jwk['alg']
        if _alg.startswith('RS'):
            public_keys[_kid] = jwt_algo.RSAAlgorithm.from_jwk(json.dumps(jwk))
        elif _alg.startswith('ES'):
            public_keys[_kid] = jwt_algo.ECAlgorithm.from_jwk(json.dumps(jwk))
        elif _alg.startswith('HS'):
            public_keys[_kid] = jwt_algo.HMACAlgorithm.from_jwk(json.dumps(jwk))
        else:
            raise_error({'message': f"Unsupported signing algorithm: {_alg}"})

    public_key = public_keys[kid]
    payload = jwt.decode(encoded_jwt, key=public_key, algorithms=[TRUSTED_BROKERS[iss]['alg']])
    return payload


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


def handler(event, context):
    """Lambda handler entrypoint for GA4GH Passport Clearinghouse for htsget endpoint authz"""

    is_authorized = False
    message = ""

    try:
        encoded_token = extract_token(event)
        verify_jwt_structure(encoded_token)
        claims = get_verified_jwt_claims(encoded_token)

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

    except ValueError as e:
        message = str(e)

    authz_resp = {
        'isAuthorized': is_authorized,
        'context': {
            'message': str(message)
        }
    }

    return authz_resp
