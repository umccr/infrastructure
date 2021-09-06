from unittest.case import TestCase

import lambda_helper


def make_mock_event(mock_token):
    return {
        "version": "2.0",
        "type": "REQUEST",
        "routeArn": "arn:aws:execute-api:ap-southeast-2:123456789:aaa1gggcct/$default/GET/reads/giab.NA12878.NIST7086.1",
        "identitySource": [f"Bearer {mock_token}"],
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
            "x-forwarded-proto": "https",
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
                "userAgent": "curl/7.69.1",
            },
            "requestId": "ZuqGrHudSwMEP4w=",
            "routeKey": "ANY /reads/giab.NA12878.NIST7086.1",
            "stage": "$default",
            "time": "25/Jan/2021:23:40:11 +0000",
            "timeEpoch": 1611618011254,
        },
    }


class TestLambdaHelperUnitTest(TestCase):
    def setUp(self) -> None:
        self.mock_token = "ASDOASDOASDKAOSD"
        self.mock_event = make_mock_event(self.mock_token)

    def test_extract_token(self):
        tok = lambda_helper.extract_bearer_token(self.mock_event)

        self.assertEqual(tok, self.mock_token)
