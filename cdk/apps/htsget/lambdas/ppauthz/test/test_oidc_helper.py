from unittest import TestCase

import responses

from oidc_helper import get_oidc_configuration
from test.mock_issuer import setup_mock_issuer


class OidcHelperUnitTest(TestCase):

    def setUp(self) -> None:
        pass

    def test_google(self):
        c = get_oidc_configuration("https://accounts.google.com")

        assert "https://accounts.google.com" == c.issuer
        assert ["RS256"] == c.algorithms

        for jwk in c.jwks.keys:
            signing_key = c.get_signing_key(jwk.key_id)

            # ok given google rotate keys there really isn't anything stable we can assert
            # here regarding the actual keys or ids!
            assert "RSA" == signing_key.key_type
            assert 40 == len(signing_key.key_id)

    def test_cache(self):
        c1 = get_oidc_configuration("https://accounts.google.com")
        c2 = get_oidc_configuration("https://accounts.google.com")

        assert c1 == c2

        get_oidc_configuration.cache_clear()

        c3 = get_oidc_configuration("https://accounts.google.com")

        assert c2 != c3

    @responses.activate
    def test_mocking(self):
        setup_mock_issuer("https://foo.bar")

        c = get_oidc_configuration("https://foo.bar")

        self.assertIsNotNone(c.get_signing_key("rsatestkey"))
