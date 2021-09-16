import logging
import os
from typing import Any

from lambda_helper import extract_bearer_token
from ppauthz import is_request_allowed_with_passport_jwt


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
        "queryStringParameters": {"referenceName": "chr1", "x": "1,2"},   <---- NOTE: this was what happened for x=1&x=2
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
        print(event)

        htsget_trusted_brokers_string = os.environ["HTSGET_TRUSTED_BROKERS"]

        if not htsget_trusted_brokers_string:
            raise Exception("HTSGET_TRUSTED_BROKERS must be specified in the lambda environment")

        htsget_trusted_visas_string = os.environ["HTSGET_TRUSTED_VISAS"]

        if not htsget_trusted_visas_string:
            raise Exception("HTSGET_TRUSTED_VISAS must be specified in the lambda environment")

        # have configured API gateway to break up the path we are authorising
        path_params = event.get("pathParameters", {})

        i = path_params.get("id")

        if not i:
            raise Exception(
                "No id in the API gateway path parameter setup for this authoriser"
            )

        encoded_jwt = extract_bearer_token(event)

        # there may not always be query parameters in which case we want to continue but just with an empty dict
        query_params = event.get("queryStringParameters", {})
        query_headers = event.get("headers", {})

        is_authorized = is_request_allowed_with_passport_jwt(
            i,
            query_params,
            query_headers,
            encoded_jwt,
            htsget_trusted_brokers_string.split(),
            htsget_trusted_visas_string.split(),
        )

        return {
            "isAuthorized": is_authorized,
        }

    except Exception as e:
        logger.exception("During htsget authorisation")

        return {"isAuthorized": False, "context": {"message": str(e)}}
