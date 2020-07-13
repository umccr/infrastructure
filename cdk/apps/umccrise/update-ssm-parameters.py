#!/usr/bin/env python3
import os
import boto3
import argparse
import json

# TODO: add logging?

ssm_client = boto3.client('ssm')
sts_client = boto3.client('sts')
USER = os.environ.get('USER', default='unknown')


def check_account(params):
    aws_account = sts_client.get_caller_identity()['Account']
    if aws_account != params['Account']:
        raise ValueError(f"Account mismatch! Expected {params['Account']} got {aws_account}")

    if aws_account == '472057503814':
        aws_account_name = 'prod'
    if aws_account == '843407916570':
        aws_account_name = 'dev'

    return aws_account_name


def fetch_parameters(params: dict):
    params = ssm_client.get_parameters(Names=list(params.keys()))
    return params


def set_parameter(name: str, value: str, type: str, env: str):
    print(f"Updating {name}: {value} as {type}")
    ssm_client.put_parameter(
        Name=name,
        Value=value,
        Type=type,
        Overwrite=True)
    ssm_client.add_tags_to_resource(
        ResourceType='Parameter',
        ResourceId=name,
        Tags=[
            {'Key': 'Creator', 'Value': USER},
            {'Key': 'Environment', 'Value': env},
            {'Key': 'Stack', 'Value': 'manual'}
        ]
    )


def values_match(param_name: str, param_value: str, params: dict):
    if not params.get(param_name):
        raise ValueError(f"Parameter not found: {param_name}")
    return params[param_name]['Value'] == param_value


if __name__ == "__main__":
    ################################################################################
    # argument parsing

    parser = argparse.ArgumentParser(description='Update SSM parameters')
    parser.add_argument('param_file', help="Parameter JSON file")

    args = parser.parse_args()
    param_file = args.param_file

    with open(param_file) as f:
        param_json = json.load(f)
    account_name = check_account(param_json)

    params = fetch_parameters(param_json['Parameters'])
    for p in params['Parameters']:
        p_name = p['Name']
        if values_match(p_name, p['Value'], param_json['Parameters']):
            print(f"Values already match for parameter: {p_name}")
        else:
            print(f"Updating value for parameter: {p_name}")
            set_parameter(
                name=p_name,
                value=param_json['Parameters'][p_name]['Value'],
                type=param_json['Parameters'][p_name]['Type'],
                env=account_name)
    for p_name in params['InvalidParameters']:
        print(f"Creating new parameter: {p_name}")
        set_parameter(
            name=p_name,
            value=param_json['Parameters'][p_name]['Value'],
            type=param_json['Parameters'][p_name]['Type'],
            env=account_name)
