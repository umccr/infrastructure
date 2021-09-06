import os
from unittest.case import TestCase, skip

import jwt_helper

INVALID_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InNvbWVraWQxIn0.eyJpc3MiOiJodHRwczovL2l" \
                "zczEudW1jY3Iub3JnIiwic3ViIjoiMTIzNDU2Nzg5MCIsIm5hbWUiOiJKb2huIERvZSIsImlhdCI6MTUxNj" \
                "IzOTAyMiwiZXhwIjoxNTE2MjM5MDIyLCJnYTRnaF92aXNhX3YxIjp7InR5cGUiOiJDb250cm9sbGVkQWNjZ" \
                "XNzR3JhbnRzIiwiYXNzZXJ0ZWQiOjE1NDk2MzI4NzIsInZhbHVlIjoiaHR0cHM6Ly91bWNjci5vcmcvaW52" \
                "YWxpZC8xIiwic291cmNlIjoiaHR0cHM6Ly9ncmlkLmFjL2luc3RpdHV0ZXMvZ3JpZC4wMDAwLjBhIiwiYnk" \
                "iOiJkYWMifX0.5DIqppX02Rkw2Ebk4KgvPlbKVBwS1dPiSeLaLLQDjBg"


class JwtHelperUnitTest(TestCase):
    def test_verify_jwt_structure_correct(self):
        # we return None and don't through an exception if the structure is ok
        self.assertIsNone(jwt_helper.verify_jwt_structure(INVALID_TOKEN))

    def test_verify_jwt_structure_incorrect(self):
        with self.assertRaises(Exception):
            jwt_helper.verify_jwt_structure("This is clearly not a token")
