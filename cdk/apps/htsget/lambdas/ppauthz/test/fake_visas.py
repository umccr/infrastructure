import base64
import time
import json
from typing import cast, Any

import responses
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from requests import PreparedRequest, Request


def create_fake_4k_visa(data_id: str, kid: str, ed_private_key: Ed25519PrivateKey) -> Any:
    """
    """
    exp = int(time.time()) + 60*60

    visa_content = f"c:{data_id} et:{exp} iu:https://nagim.dev/p/abcde-12345-grety iv:randomstring"

    signature = ed_private_key.sign(visa_content.encode("utf8"))

    return {
      "v": visa_content,
      "k": kid,
      "s": base64.urlsafe_b64encode(signature).rstrip(b"=").decode("ascii")
    }

