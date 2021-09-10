import logging
from typing import Any

from lambda_helper import extract_bearer_token
from ppauthz import test_passport_jwt


logger = logging.getLogger(__name__)


def handler(event: Any, _) -> Any:
    """
    Lambda handler entrypoint for GA4GH Passport Clearinghouse for htsget endpoint authz

    Sample event:
    {
        "version": "2.0",
        "type": "REQUEST",
        "routeArn": "arn:aws:execute-api:ap-southeast-2:843407916570:jyp1fujvkf/$default/GET/variants/data/10g/https/HG00096",
        "identitySource": ["Bearer sdasdasdadadrr"],
        "routeKey": "ANY /variants/data/10g/https/{id}",
        "rawPath": "/variants/data/10g/https/HG00096",
        "rawQueryString": "referenceName=chr1&x=1&x=2",
        "headers": {
            "accept": "*/*",
            "accept-encoding": "gzip, deflate, br",
            "authorization": "Bearer sdasdasdadadrr",
            "cache-control": "no-cache",
            "content-length": "0",
            "host": "htsget.dev.umccr.org",
            "htsgetcurrentblock": "0",
            "htsgettotalblocks": "2",
            "postman-token": "e7cde245-bcab-428c-84d2-fb40cee75080",
            "user-agent": "PostmanRuntime/7.28.4",
            "x-amzn-trace-id": "Root=1-61386648-63c24bd1207350ce6dd4b3ab",
            "x-forwarded-for": "58.7.96.122",
            "x-forwarded-port": "443",
            "x-forwarded-proto": "https",
        },
        "queryStringParameters": {"referenceName": "chr1", "x": "1,2"},
        "requestContext": {
            "accountId": "843407916570",
            "apiId": "jyp1fujvkf",
            "domainName": "htsget.dev.umccr.org",
            "domainPrefix": "htsget",
            "http": {
                "method": "GET",
                "path": "/variants/data/10g/https/HG00096",
                "protocol": "HTTP/1.1",
                "sourceIp": "58.7.96.122",
                "userAgent": "PostmanRuntime/7.28.4",
            },
            "requestId": "FVTrahNBSwMEJ1g=",
            "routeKey": "ANY /variants/data/10g/https/{id}",
            "stage": "$default",
            "time": "08/Sep/2021:07:29:12 +0000",
            "timeEpoch": 1631086152863,
        },
        "pathParameters": {"id": "HG00096"},
    }

    """
    logger.setLevel(logging.INFO)

    try:
        encoded_jwt = extract_bearer_token(event)

        path_params = event.get("pathParameters", {})

        id = path_params.get("id")

        if not id:
            raise Exception(
                "No id in the API gateway path parameter setup for this authoriser"
            )

        # these may not be here in which case we want to continue but just with an empty dict
        query_params = event.get("queryStringParameters", {})

        is_authorized = test_passport_jwt(
            id,
            query_params,
            encoded_jwt,
            # need these to be set from outer config
            ["https://test.cilogon.org"],
            ["https://didact-patto.dev.umccr.org"],
        )

        return {
            "isAuthorized": True,
        }

    except Exception as e:
        logger.exception("During htsget authorisation")

        return {"isAuthorized": False, "context": {"message": str(e)}}
