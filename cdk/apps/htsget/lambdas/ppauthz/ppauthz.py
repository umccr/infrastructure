import json
import logging
import re
from datetime import datetime, timedelta
from typing import List

import jwt
import requests
from jwt import algorithms as jwt_algo
from jwt import PyJWKClient

from constants import GA4GH_PASSPORT_V1, GA4GH_PASSPORT_V2, GA4GH_PASSPORT_V2_ISSUERS, GA4GH_VISA_V1
from jwt_helper import verify_jwt_structure, get_verified_jwt_claims, get_verified_visa_claims

logger = logging.getLogger(__name__)


ALLOWED_AUDIENCE = [
    "htsget.dev.umccr.org",
    "htsget.umccr.org",
]


def test_passport_jwt(htsget_id: str, htsget_parameters: str, encoded_jwt: str, trusted_brokers: List[str], trusted_visa_issuers: List[str]) -> bool:
    # simple test right at the start to ensure that the token is at least basically structured like a JWT
    verify_jwt_structure(encoded_jwt)

    claims = get_verified_jwt_claims(encoded_jwt, trusted_brokers)

    is_authorized = False

    if "sub" in claims and claims["sub"].starts_with("https://nagim.dev"):
        iss = "https://didact-patto.dev.umccr.org"
        visa_claims = {
            "c": "8XZF4195109CIIERC35P577HAM"
        }
        if "c" in visa_claims:
            manifest = requests.get(f"{iss}/api/manifest/{visa_claims['c']}").json()

            print(manifest)

    if GA4GH_PASSPORT_V1 in claims.keys():
        # client provided PASSPORT token
        encoded_visas = claims[GA4GH_PASSPORT_V1]
        for encoded_visa in encoded_visas:  # search appropriate visa in a passport, use the first found
            verify_jwt_structure(encoded_visa)
            visa_claims = get_verified_jwt_claims(encoded_visa)
            if perform_visa_check(visa_claims):
                is_authorized = True
                break

    if GA4GH_PASSPORT_V2 in claims.keys():
        # new 4k passport format
        passport = claims[GA4GH_PASSPORT_V2]

        issuers = passport.get(GA4GH_PASSPORT_V2_ISSUERS, {})

        for iss in issuers.keys():
            # it is not illegal for the passport to have an issuer we do not trust, its just we don't
            # want to do anything with them
            if iss not in trusted_visa_issuers:
                logger.debug(f"Skipped visa issuer {iss} in passport from broker {claims['iss']}")
                continue

            visa_raw = issuers[iss]

            # check base validity of visa TBD

            # verify the signature of the content of the visa
            visa_claims = get_verified_visa_claims(iss, visa_raw["v"], visa_raw["k"], visa_raw["s"])

            # use our logic to see if we can authorise this request

            # we have been given a content visa - and it is from an issuer that we know the protocol of
            # so we do a back channel request for manifest
            # TBD cache
            if "c" in visa_claims:
                # regex check on format of c
                manifest = requests.get(f"{iss}/api/manifest/{visa_claims['c']}").json()

                print(manifest)

    return is_authorized


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


