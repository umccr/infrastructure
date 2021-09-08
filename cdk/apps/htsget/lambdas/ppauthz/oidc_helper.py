from dataclasses import dataclass
from functools import lru_cache
from typing import Any, List, Dict

import requests
from jwt import PyJWKSet, PyJWK


@dataclass
class OidcConfiguration:
    issuer: str

    configuration: Dict[str, Any]

    algorithms: List[str]
    jwks: PyJWKSet

    def get_signing_key(self, kid: str) -> PyJWK:
        signing_key = None

        for jwk_set_key in self.jwks.keys:
            if jwk_set_key.key_type == "RSA":
                if jwk_set_key.public_key_use == "sig" and jwk_set_key.key_id:
                    if jwk_set_key.key_id == kid:
                        signing_key = jwk_set_key
                        break
            else:
                if jwk_set_key.key_id == kid:
                    signing_key = jwk_set_key
                    break

        if not signing_key:
            raise Exception(
                f'Unable to find a signing key that matches: "{kid}"'
            )

        return signing_key


@lru_cache
def get_oidc_configuration(issuer: str) -> OidcConfiguration:
    """
    For the given issuer fetch relevant openid configuration and JWKS. Cache the values in an LRU cache
    as the intended use of this is within a lambda that inherently has a limited lifespan (expected
    lambda lifespan << JWKS lifespan)

    Args:
        issuer: a generally trusted issuer URL

    Returns:

    Notes:
        it is not acceptable to pass blindly any issuer URL to this function - only issuers that
        are inherently believed to be trusted (i.e. in a whilelist) should be passed here. Otherwise
        a JWT could specify an arbitrary issuer and we would try to execute an arbitrary HTTP fetch
        (which is not good).
    """
    # https://ldapwiki.com/wiki/Openid-configuration
    well_known_config: Dict[str, Any] = requests.get(f"{issuer}/.well-known/openid-configuration").json()

    jwks_uri = well_known_config.get('jwks_uri')

    if not jwks_uri:
        raise Exception(f"Issuer {issuer} had no discoverable openid-configuration")

    # fetch the known key file too
    jwks_content = requests.get(jwks_uri).json()

    # get the full JWKS in a smarter object
    jwks = PyJWKSet.from_dict(jwks_content)

    # it is useful to know the algorithms that this endpoint believes it supports
    algorithms = well_known_config.get("id_token_signing_alg_values_supported", [])

    # this algorithm is _required_ for all openid - but this logic captures the case where the
    # endpoint does indeed support RS256 but just didn't have a signing alg values entry
    if "RS256" not in algorithms:
        algorithms.append("RS256")

    return OidcConfiguration(
        issuer=issuer,
        configuration=well_known_config,
        algorithms=algorithms,
        jwks=jwks
    )
