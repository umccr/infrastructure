import os
from unittest.case import TestCase

import ppauthz

INVALID_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InNvbWVraWQxIn0.eyJpc3MiOiJodHRwczovL2lzczEudW1jY3Iub3JnIiwic3ViIjoiMTIzNDU2Nzg5MCIsIm5hbWUiOiJKb2huIERvZSIsImlhdCI6MTUxNjIzOTAyMiwiZXhwIjoxNTE2MjM5MDIyLCJnYTRnaF92aXNhX3YxIjp7InR5cGUiOiJDb250cm9sbGVkQWNjZXNzR3JhbnRzIiwiYXNzZXJ0ZWQiOjE1NDk2MzI4NzIsInZhbHVlIjoiaHR0cHM6Ly91bWNjci5vcmcvaW52YWxpZC8xIiwic291cmNlIjoiaHR0cHM6Ly9ncmlkLmFjL2luc3RpdHV0ZXMvZ3JpZC4wMDAwLjBhIiwiYnkiOiJkYWMifX0.5DIqppX02Rkw2Ebk4KgvPlbKVBwS1dPiSeLaLLQDjBg"


def make_mock_event(mock_token):
    return {
        "version": "2.0",
        "type": "REQUEST",
        "routeArn": "arn:aws:execute-api:ap-southeast-2:123456789:aaa1gggcct/$default/GET/reads/giab.NA12878.NIST7086.1",
        "identitySource": [
            f"Bearer {mock_token}"
        ],
        "routeKey": "ANY /reads/giab.NA12878.NIST7086.1",
        "rawPath": "/reads/giab.NA12878.NIST7086.1",
        "rawQueryString": "",
        "headers": {
            "accept": "*/*",
            "authorization": f"Bearer {mock_token}",
            "content-length": "0",
            "host": "htsget.some.org",
            "user-agent": "curl/7.69.1",
            "x-amzn-trace-id": "Root=1-600f56db-41dc5dac31f68e8253bbb29a",
            "x-forwarded-for": "111.222.333.444",
            "x-forwarded-port": "443",
            "x-forwarded-proto": "https"
        },
        "requestContext": {
            "accountId": "123456789",
            "apiId": "aaa1gggcct",
            "domainName": "htsget.some.org",
            "domainPrefix": "htsget",
            "http": {
                "method": "GET",
                "path": "/reads/giab.NA12878.NIST7086.1",
                "protocol": "HTTP/1.1",
                "sourceIp": "111.222.333.444",
                "userAgent": "curl/7.69.1"
            },
            "requestId": "ZuqGrHudSwMEP4w=",
            "routeKey": "ANY /reads/giab.NA12878.NIST7086.1",
            "stage": "$default",
            "time": "25/Jan/2021:23:40:11 +0000",
            "timeEpoch": 1611618011254
        }
    }


class PassportAuthzUnitTest(TestCase):

    def setUp(self) -> None:
        self.mock_token = INVALID_TOKEN
        self.mock_event = make_mock_event(self.mock_token)

    def test_extract_token(self):
        """
        cd lambdas/ppauthz
        python -m unittest test_ppauthz.PassportAuthzUnitTest.test_extract_token
        """
        tok = ppauthz.extract_token(self.mock_event)
        print(tok)
        self.assertEqual(tok, self.mock_token)

    def test_verify_jwt_structure(self):
        """
        cd lambdas/ppauthz
        python -m unittest test_ppauthz.PassportAuthzUnitTest.test_verify_jwt_structure
        """
        tok = ppauthz.extract_token(self.mock_event)
        self.assertTrue(ppauthz.verify_jwt_structure(tok))

    def test_handler(self):
        """
        cd lambdas/ppauthz
        python -m unittest test_ppauthz.PassportAuthzUnitTest.test_handler
        """
        with self.assertRaises(ValueError):
            ppauthz.handler(self.mock_event, None)


class PassportAuthzIntegrationTest(TestCase):

    def setUp(self) -> None:
        self.mock_token = os.getenv('PASSPORT_VISA_TOKEN')
        self.mock_event = make_mock_event(self.mock_token)

    def test_handler_it(self):
        """Login to Labtec to grab fresh visa token and export as PASSPORT_VISA_TOKEN env var. Ignore IT test otherwise!
        Login Labtec > Userinfo -> ga4gh_passport_v1 -> Copy first visa token (i.e meant for umccr, check with Andrew)
        Then, export the passport visa token

            export PASSPORT_VISA_TOKEN=eyJ0...

        Then, run the test

            cd lambdas/ppauthz
            python -m unittest test_ppauthz.PassportAuthzIntegrationTest.test_handler_it
        """
        lmbda_resp: dict = ppauthz.handler(self.mock_event, None)
        self.assertTrue(lmbda_resp['isAuthorized'])
