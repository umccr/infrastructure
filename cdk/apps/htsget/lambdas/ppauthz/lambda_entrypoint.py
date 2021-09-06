import logging
import re
from typing import Any

from lambda_helper import extract_bearer_token
from ppauthz import test_passport_jwt


logger = logging.getLogger(__name__)


def handler(event: Any, _) -> Any:
    """
    Lambda handler entrypoint for GA4GH Passport Clearinghouse for htsget endpoint authz
    """
    logger.setLevel(logging.INFO)

    try:
        encoded_jwt = extract_bearer_token(event)

        is_authorized = test_passport_jwt(encoded_jwt)

        return {
            'isAuthorized': is_authorized,
        }

    except Exception as e:
        logger.exception("During htsget authorisation")

        return {
            'isAuthorized': False,
            'context': {
                'message': str(e)
            }
        }


