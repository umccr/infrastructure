import base64
import json
import struct

import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa, ed25519
from cryptography.hazmat.backends import default_backend
import responses
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPrivateKey


def setup_mock_issuer(issuer: str) -> RSAPrivateKey:
    """
    Using the responses library - sets up fake endpoints and tokens that can be used for a variety of
    test purposes.

    Args:
        issuer: the fake https://blah... issuer

    Returns:

    """
    openid_url = f"{issuer}/.well-known/openid-configuration"
    jwks_url = f"{issuer}/.well-known/jwks"

    rsa_private = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    ed_private_key = ed25519.Ed25519PrivateKey.generate()

    def openid_config_callback(request):
        resp_body = {
            "issuer": issuer,
            "jwks_uri": jwks_url,
            "id_token_signing_alg_values_supported": ["RS256"],
            "scopes_supported": ["openid", "email", "profile"],
        }

        headers = {"request-id": "728d329e-0e86-11e4-a748-0c84dc037c13"}

        return 200, headers, json.dumps(resp_body)

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
                    "e": long_to_base64(rsa_private.public_key().public_numbers().e),
                    "alg": "RS256",
                    "n": long_to_base64(rsa_private.public_key().public_numbers().n),
                    "kid": "rsatestkey",
                    "use": "sig",
                },
                {
                    "kty": "OKP",
                    "crv": "Ed25519",
                    "kid": "edtestkey",
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

        print(resp_body)

        return 200, {}, json.dumps(resp_body)

    responses.add_callback(
        responses.GET,
        jwks_url,
        callback=jwks_callback,
        content_type="application/json",
    )

    return rsa_private


# https://github.com/rohe/pyjwkest/blob/master/src/jwkest/__init__.py
# would prefer to use a library but this library seems unmaintained and large to access just these
# two funcs..
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
