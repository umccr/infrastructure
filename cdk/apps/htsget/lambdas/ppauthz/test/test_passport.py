from unittest import TestCase

import jwt
import responses

from oidc_helper import get_oidc_configuration
from ppauthz import test_passport_jwt
from test.mock_issuer import setup_mock_issuer


class PassportUnitTest(TestCase):
    @responses.activate
    def test_simple(self):
        rsa_private = setup_mock_issuer("https://umccr.ninja")

        encoded_jwt = jwt.encode(
            {"some": "payload", "iss": "https://umccr.ninja", "aud": "foo"},
            rsa_private,
            algorithm="RS256",
            headers={"kid": "rsatestkey"},
        )

        # c = get_oidc_configuration("https://umccr.ninja")
        # c.get_signing_key("testkey")

        test_passport_jwt(encoded_jwt)
