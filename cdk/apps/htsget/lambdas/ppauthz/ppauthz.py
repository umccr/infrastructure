import logging
from typing import List, Any, Dict

import requests

from constants import (
    GA4GH_PASSPORT_V1,
    GA4GH_PASSPORT_V2,
    GA4GH_PASSPORT_V2_ISSUERS,
    GA4GH_VISA_V1,
)
from jwt_helper import (
    verify_jwt_structure,
    get_verified_jwt_claims,
    get_verified_visa_claims,
)

logger = logging.getLogger(__name__)


ALLOWED_AUDIENCE = [
    "htsget.dev.umccr.org",
    "htsget.umccr.org",
]


def is_request_allowed_with_passport_jwt(
    htsget_id: str,
    htsget_parameters: Dict[str, Any],
    htsget_headers: Dict[str, Any],
    encoded_jwt: str,
    trusted_brokers: List[str],
    trusted_visa_issuers: List[str],
) -> bool:
    """
    Test whether this htsget request should be allowed based on the visas/passport.

    Args:
        htsget_id:
        htsget_parameters:
        htsget_headers:
        encoded_jwt: the base64 encoded JWT
        trusted_brokers:
        trusted_visa_issuers:

    Returns:
        true if the person with this passport should be allowed through to access the data
    """
    # simple test right at the start to ensure that the token is at least basically structured like a JWT
    verify_jwt_structure(encoded_jwt)

    # decode into proper claims object but only if correctly signed by a broker we trust
    claims = get_verified_jwt_claims(encoded_jwt, trusted_brokers)

    if GA4GH_PASSPORT_V1 in claims.keys():
        # client provided PASSPORT token
        encoded_visas = claims[GA4GH_PASSPORT_V1]
        for (
            encoded_visa
        ) in (
            encoded_visas
        ):  # search appropriate visa in a passport, use the first found
            verify_jwt_structure(encoded_visa)
            visa_claims = get_verified_jwt_claims(encoded_visa, trusted_brokers)
            if perform_visa_check(visa_claims):
                return True

    if GA4GH_PASSPORT_V2 in claims.keys():
        # new 4k passport format
        passport = claims[GA4GH_PASSPORT_V2]

        issuers = passport.get(GA4GH_PASSPORT_V2_ISSUERS, {})

        print(
            f"htsget of {htsget_id} with params {htsget_parameters} and headers {htsget_headers}"
        )
        print(f"Received visas {issuers}")

        for iss in issuers.keys():
            # it is not illegal for the passport to have an issuer we do not trust, its just we don't
            # want to do anything with them
            if iss not in trusted_visa_issuers:
                logger.debug(
                    f"Skipped visa issuer {iss} in passport from broker {claims['iss']}"
                )
                continue

            visa_raw = issuers[iss]

            # check base validity of visa TBD

            # verify the signature of the content of the visa
            visa_claims = get_verified_visa_claims(
                iss, visa_raw["v"], visa_raw["k"], visa_raw["s"]
            )

            # use our logic to see if we can authorise this request

            # we have been given a content visa - and it is from an issuer that we know the protocol of
            # so we do a back channel request for manifest
            # TBD cache
            if "c" in visa_claims:
                manifest_id = visa_claims["c"]

                # TODO: regex check on format of manifest id
                if not manifest_id:
                    raise Exception(
                        f"Controlled data set id from issuer {iss} was not understood"
                    )

                manifest = requests.get(f"{iss}/api/manifest/{manifest_id}").json()

                print(
                    f"Received manifest for controlled data set {manifest_id} {manifest}"
                )

                # e.g. manifest
                # {'id': '8XZF4195109CIIERC35P577HAM',
                # 'htsgetUrl': 'https://htsget.dev.umccr.org',
                # 'artifacts': {'reads/10g/https/HG00096': {},
                # 'variants/10g/https/HG00096': {},
                # 'variants/10g/https/HG00097': {
                #     'restrict_to_regions': [
                #         { chromosome: 'chr1'},
                #         { chromosome: 'chr2'},
                #         { chromosome: 'chr3' }
                #         ]},
                # 'variants/10g/https/HG00099': {'restrict_to_regions': [
                # { chromosome: 'chr11'},
                # { chromosome: 'chr12'}]}}}

                # this is some very custom terrible logic
                # TODO: fix this logic to be less specific to this exact manifest

                if manifest["id"] != manifest_id:
                    raise Exception(
                        "Returned manifest from issuer did not have a correctly matching controlled data set id"
                    )

                manifest_artifacts: Dict[str, Any] = manifest.get("artifacts", {})

                for a, rules in manifest_artifacts.items():
                    if a.startswith("variants") and a.endswith(htsget_id):
                        # the reference htsget server - when serving up header data - uses a generic path
                        # that does not include chromosome or start/end - which makes sense as it is the same
                        # header for the entire file.. but that means we need to skip any rules processing once
                        # we know they are basically allowed to see the file
                        if "htsgetblockclass" in htsget_headers:
                            if htsget_headers["htsgetblockclass"] == "header":
                                return True

                        # if the rules is empty then this is defacto permission to access this whole
                        # sample
                        if not rules:
                            print(
                                f"Authorised full access to {a} because there was no accompanying rule in manifest"
                            )
                            return True

                        restrict_rules = rules.get("restrict_to_regions", [])

                        # if there are no restrictions on regions in the manifest then all requests succeed
                        # because we have at least matched up the htsget id to one in the manifest
                        if len(restrict_rules) == 0:
                            print(
                                f"Authorised full access to {a} because there was no region restriction rule in manifest"
                            )
                            return True

                        # once we know we have some rules - we really need to insist that
                        # they are fetching partial files i.e. they must specify a chromosome
                        if "referenceName" not in htsget_parameters:
                            print(
                                f"Refused access to {a}/{restrict_rules} because no chromosome (i.e. referenceName) was listed in the htsget call but there are rules"
                            )
                            return False

                        requested_chromosome = htsget_parameters["referenceName"]

                        for restrict_rule in restrict_rules:
                            if "chromosome" in restrict_rule:
                                allowed_chromosome = restrict_rule.get(
                                    "chromosome", None
                                )

                                if requested_chromosome == allowed_chromosome:
                                    print(
                                        f"Authorised access to {a}/{allowed_chromosome} because that was allowed by rule {restrict_rule}"
                                    )
                                    return True
                                else:
                                    print(
                                        f"Refused access to {a}/{allowed_chromosome} because {requested_chromosome} was not in the rule {restrict_rule}.. continuing rules processing"
                                    )

                        return False

    return False


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

    visa_type = visa["type"]
    visa_asserted = visa["asserted"]
    visa_value = visa["value"]
    visa_source = visa["source"]
    visa_by: str = visa.get("by", "null")

    return (
        visa_type == "ControlledAccessGrants"
        and "https://umccr.org/datasets/710" in visa_value
    )
