import base64
import json
import struct
from typing import Tuple

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa, ed25519
import responses
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPrivateKey

MOCK_ISSUER_RSA_KID = "rsatestkey"
MOCK_ISSUER_ED_KID = "edtestkey"


def setup_mock_issuer(issuer: str) -> Tuple[RSAPrivateKey, Ed25519PrivateKey]:
    """
    Using the responses library - sets up fake endpoints and tokens that can be used for a variety of
    test purposes. Returns the private RSA etc keys created during the mocking.

    Args:
        issuer: the fake https://blah... issuer

    Returns:
        a Tuple of private keys
    """
    openid_url = f"{issuer}/.well-known/openid-configuration"
    jwks_url = f"{issuer}/.well-known/jwks"

    rsa_private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    ed_private_key = ed25519.Ed25519PrivateKey.generate()

    def openid_config_callback(request):
        resp_body = {
            "issuer": issuer,
            "jwks_uri": jwks_url,
            "id_token_signing_alg_values_supported": ["RS256"],
            "scopes_supported": ["openid", "email", "profile"],
        }

        return 200, { }, json.dumps(resp_body)

    responses.add_callback(
        responses.GET,
        openid_url,
        callback=openid_config_callback,
        content_type="application/json",
    )

    def jwks_callback(request):
        resp_body = {
            "keys": [
                {
                    "kty": "RSA",
                    "e": long_to_base64(rsa_private_key.public_key().public_numbers().e),
                    "alg": "RS256",
                    "n": long_to_base64(rsa_private_key.public_key().public_numbers().n),
                    "kid": MOCK_ISSUER_RSA_KID,
                    "use": "sig",
                },
                {
                    "kty": "OKP",
                    "crv": "Ed25519",
                    "kid": MOCK_ISSUER_ED_KID,
                    "alg": "EdDSA",
                    "x": base64.urlsafe_b64encode(
                        ed_private_key.public_key().public_bytes(
                            serialization.Encoding.Raw, serialization.PublicFormat.Raw
                        )
                    )
                    .rstrip(b"=")
                    .decode("ascii"),
                },
            ]
        }

        return 200, {}, json.dumps(resp_body)

    responses.add_callback(
        responses.GET,
        jwks_url,
        callback=jwks_callback,
        content_type="application/json",
    )

    return rsa_private_key, ed_private_key


# https://github.com/rohe/pyjwkest/blob/master/src/jwkest/__init__.py
# would prefer to use a library but this library seems unmaintained and large to access just these
# two funcs.. so good old copy paste
def long2intarr(long_int):
    _bytes = []
    while long_int:
        long_int, r = divmod(long_int, 256)
        _bytes.insert(0, r)
    return _bytes


def long_to_base64(n):
    bys = long2intarr(n)
    data = struct.pack("%sB" % len(bys), *bys)
    if not len(data):
        data = "\x00"
    s = base64.urlsafe_b64encode(data).rstrip(b"=")
    return s.decode("ascii")
