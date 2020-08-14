#!/usr/bin/env python3

"""
Wrapper around the cromwell api
"""

import os
import argparse
from pathlib import Path

from cromwell_tools import api
from cromwell_tools import utilities
from cromwell_tools.cromwell_auth import CromwellAuth


# Set defaults
DEFAULT_WEBSERVICE_PORT=8000
DEFAULT_WORKFLOW_OPTIONS=Path("/opt/cromwell/configs/options.json")


def get_args():
    parser = argparse.ArgumentParser(description="Submit workflow to cromwell server")
    parser.add_argument("--workflow-source",
                        required=True,
                        help="Path to workflow code")
    parser.add_argument("--workflow-inputs",
                        required=True,
                        help="Path to workflow inputs configuration")
    parser.add_argument("--workflow-dependencies",
                        required=False,
                        help="Zip file containing workflow dependencies")
    parser.add_argument("--webservice-port",
                        type=int,
                        required=False, default=DEFAULT_WEBSERVICE_PORT,
                        help="Port that cromwell is running on")
    parser.add_argument("--workflow-options-json",
                        required=False, default=DEFAULT_WORKFLOW_OPTIONS,
                        help="Options.json file")

    return parser.parse_args()


def check_args(args):
    """
    Ensure that each file is as expected
    :return:
    """
    # Convert workflow source to path object
    workflow_source_arg = getattr(args, "workflow_source", None)
    workflow_source = Path(workflow_source_arg)
    if not workflow_source.is_file():
        sys.exit(1)
    setattr(args, "workflow_source", workflow_source)

    # Convert workflow inputs to path object
    workflow_inputs_arg = getattr(args, "workflow_inputs", None)
    workflow_inputs = Path(workflow_inputs_arg)
    if not workflow_inputs.is_file():
        sys.exit(1)
    setattr(args, "workflow_inputs", workflow_inputs)

    # Check workflow dependencies is a zip file, otherwise exit
    workflow_dependencies_arg = getattr(args, "workflow_dependencies", None)
    if workflow_dependencies_arg is not None:
        workflow_dependencies = Path(workflow_dependencies_arg)
        if not workflow_dependencies.is_file():
            sys.exit(1)
        setattr(args, "workflow_dependencies", workflow_dependencies)

    # Check options is a file
    workflow_options_json_arg = getattr(args, "workflow_options_json", None)
    if workflow_options_json_arg is not None:
        workflow_options_json = Path(workflow_options_json_arg)
        if not workflow_options_json.is_file():
            sys.exit(1)
        setattr(args, "workflow_options_json", workflow_options_json)

    return args

def submit_to_cromwell(args):
    # Get authentication (as no authentication)
    auth = CromwellAuth.from_no_authentication(url="http://localhost:{}".format(args.webservice_port))

    response = api.submit(auth=auth,
                          wdl_file=args.workflow_source,
                          inputs_files=args.workflow_inputs,
                          dependencies=args.workflow_dependencies,
                          validate_labels=True)

    # FIXME - need to test this first a bit
    print(response)


def main():
    # Get args
    args = get_args()
    # Check em
    args = check_args(args)
    # Submit to cromwell
    submit_to_cromwell(args)


if __name__ == "__main__":
    main()
