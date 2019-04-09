import boto3
import botocore.vendored.requests
import http.client as http_client
import json
import urllib.parse
import logging as log
import os

# http_client.HTTPConnection.debuglevel = 5
log.basicConfig(level=log.INFO)
github_topic = "umccr-automation"
ssm_travis_key_id = "/cloud_keys/travis_token"

role_arn = os.environ.get("ROLE_ARN")
env = os.environ.get("ENV")
duration = int(os.environ.get("DURATION"))

travis_headers = {}
travis_headers['Travis-API-Version'] = '3'
github_headers = {}
github_headers['Accept'] = 'application/vnd.github.mercy-preview+json'


def upsert_var(repo, var_name, val, prefix):
    """Creates a variable if it doesn't exist, updates it if it does
    Prefixes the variable with the prefix value
    """
    prefixed_var_name = prefix + "_" + var_name
    data = {'env_var.name': var_name, 'env_var.value': val}
    var_id = get_var_id(repo,var_name)

    if var_id == "":
        log.debug("Env var " + var_name + " does not exist. Creating.")
        url = "https://api.travis-ci.com/repo/{}/env_vars".format(urllib.parse.quote_plus(repo))
        response = requests.post(url, headers=travis_headers, json=data)
    else:
        log.debug("Env var " + var_name + " exists. Updating.")
        url = "https://api.travis-ci.com/repo/{}/env_var/{}".format(urllib.parse.quote_plus(repo), var_id)
        response = requests.patch(url, headers=travis_headers, json=data)

    if response.ok:
        log.debug("Upsert var for " + var_name + " succeeded.")
    else: 
        raise Exception("upsert var for " + var_name + " failed. " + str(response.status_code) + ": " + response.text)


def get_var_id(repo,var_name):
    """Get's travis's variable ID for a given variable name and repo
    Returns ID if found, returns empty string if not
    """
    url = "https://api.travis-ci.com/repo/{}/env_vars".format(urllib.parse.quote_plus(repo))
    env_vars = requests.get(url, headers=travis_headers).json()['env_vars']

    log.debug("got vars:")
    for var in env_vars:
        if var["name"] == var_name:
            return var["id"]

    return ""


def main(event, context):
    log.info("Retrieving travis token...")

    response = boto3.client('ssm').get_parameter(
    Name=ssm_travis_key_id,
    WithDecryption=True
    )

    try:
        travis_token = response['Parameter']['Value']
    except KeyError:
        raise Exception('Unable to retrieve travis token. Does it exist at ' + ssm_travis_key_id +'?')

    travis_headers['Authorization'] = "token " + travis_token

    log.info("Generating creds...")
    creds = sts_client.get_session_token(
    RoleArn=role_arn, 
    RoleSessionName='cloud-keys',
    DurationSeconds=duration
    )['Credentials']

    response = requests.get("https://api.github.com/search/repositories?q=topic:" + github_topic, headers=github_headers)

    repos = json.loads(response.text)['items']
    headers = {}
    for repo in repos:
        repo_name = repo['full_name']
        log.info("Processing " + repo_name)
        upsert_var(repo_name, 'AWS_ACCESS_KEY_ID', creds['AccessKeyId'], env)
        upsert_var(repo_name, 'AWS_SECRET_ACCESS_KEY', creds['SecretAccessKey'], env)
        upsert_var(repo_name, 'AWS_SESSION_TOKEN', creds['SessionToken'], env)


    body = {
        "message": "Update successful.",
        "input": event
    }

    response = {
        "statusCode": 200,
        "body": json.dumps(body)
    }

    log.info(response)
    return response
   

if __name__ == "__main__":
    main('', '')