import json
from typing import cast

import responses
from requests import PreparedRequest, Request


def setup_mock_issuer_manifest(issuer: str) -> None:
    """
    Using the responses library - sets up an issuer so that it also responds to
    requests for a particular manifest.

    Args:
        issuer: the fake https://blah... issuer

    Returns:
        a Tuple of private keys
    """
    manifest_url = f"{issuer}/api/manifest"

    # the real locations of these - though this relies on config in the htsget endpoint.. revisit
    # "s3://1000genomes-dragen/data/dragen-3.6.3/hg38_altaware_nohla-cnv-anchored/HG00371/HG00371.sv.vcf.gz",
    def manifest_callback(r: PreparedRequest):
        i = cast(Request, r).params["id"]
        resp_body = {
            "id": i,
            "artifacts": {
                "variants/10g/https/HG00096": {},
                "variants/10g/https/HG00097": {"chromosomes_only": ["chr1", "chr2", "chr3"]},
                "variants/10g/https/HG00099": {"chromosomes_only": ["chr11", "chr12", "chr13"]},
            },
        }

        return 200, {"Content-Type": "application/json"}, json.dumps(resp_body)

    responses.add_callback(
        responses.GET,
        manifest_url,
        callback=manifest_callback,
        content_type="application/json",
    )
