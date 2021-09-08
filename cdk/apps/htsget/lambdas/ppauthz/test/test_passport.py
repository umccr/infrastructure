from unittest import TestCase

import jwt
import requests
import responses

from constants import GA4GH_PASSPORT_V2, GA4GH_PASSPORT_V2_ISSUERS
from oidc_helper import get_oidc_configuration
from ppauthz import test_passport_jwt
from test.fake_visas import create_fake_4k_visa
from test.mock_issuer import setup_mock_issuer, MOCK_ISSUER_RSA_KID, MOCK_ISSUER_ED_KID
from test.mock_issuer_manifest import setup_mock_issuer_manifest


FAKE_BROKER_ISSUER = "https://umccr.ninja"
FAKE_PERSON_ID = "https://nagim.dev/p/abcde-12345-grety"
FAKE_DAC_ISSUER = "https://agha.ninja"
FAKE_DAC_DATASET = "urn:fdc:australiangenomics.org.au:2018:approved/1"


class PassportUnitTest(TestCase):
    @responses.activate
    def test_simple(self):
        broker_rsa_private, broker_ed_private = setup_mock_issuer(FAKE_BROKER_ISSUER)

        dac_rsa_private, dac_ed_private = setup_mock_issuer(FAKE_DAC_ISSUER)
        setup_mock_issuer_manifest(FAKE_DAC_ISSUER)
        dac_visa = create_fake_4k_visa(
            FAKE_DAC_DATASET,
            MOCK_ISSUER_ED_KID,
            dac_ed_private,
        )

        passport_payload = {
            "iss": FAKE_BROKER_ISSUER,
            "sub": FAKE_PERSON_ID,
            "aud": "foo",
            GA4GH_PASSPORT_V2: {
                "vn": 1.2,
                GA4GH_PASSPORT_V2_ISSUERS: {
                    FAKE_DAC_ISSUER: dac_visa
                }
            }
        }

        passport_jwt = jwt.encode(
            passport_payload,
            broker_rsa_private,
            algorithm="RS256",
            headers={"kid": MOCK_ISSUER_RSA_KID},
        )

        test_passport_jwt(passport_jwt, [FAKE_BROKER_ISSUER], [FAKE_DAC_ISSUER])

