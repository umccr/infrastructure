import json
import re
from datetime import datetime, timedelta

import jwt
import requests
from jwt import algorithms as jwt_algo

ALLOWED_AUDIENCE = [
    "htsget.dev.umccr.org",
    "htsget.umccr.org",
]

TRUSTED_BROKERS = {
    'https://guppy.sandbox.genovic.org.au': {
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
    print(json.dumps(message))
    raise ValueError(message)


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


def handler(event, context):
    """Lambda handler entrypoint for GA4GH Passport Clearinghouse for htsget endpoint authz"""

    is_authorized = False

    encoded_token = extract_token(event)
    verify_jwt_structure(encoded_token)
    claims = get_verified_jwt_claims(encoded_token)

    ga4gh_visa_v1 = claims['ga4gh_visa_v1']
    visa_type = ga4gh_visa_v1['type']
    visa_asserted = ga4gh_visa_v1['asserted']
    visa_value = ga4gh_visa_v1['value']
    visa_source = ga4gh_visa_v1['source']
    visa_by: str = ga4gh_visa_v1.get('by', "null")

    # TODO ACL access rule?
    if visa_type == "ControlledAccessGrants" and "umccr" in visa_value:
        is_authorized = True

    authz_resp = {
        'isAuthorized': is_authorized,
        'context': {
            'visa_by': str(visa_by)
        }
    }

    return authz_resp
