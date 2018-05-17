import os
import json
import http.client
from urllib import parse, request
import boto3

s3 = boto3.client('s3')

st2_host = os.environ.get("ST2_HOST")
st2_url = os.environ.get("ST2_API_URL")
st2_api_token = os.environ.get("ST2_API_KEY")

headers = {
    'St2-Api-Key': st2_api_token,
    'Content-Type': 'application/json',
}

def st2_callback(fname):
    connection = http.client.HTTPSConnection(st2_host)

    params = json.dumps({"trigger": "pcgr.up", "payload": {"status": "done", 
                                                           "task": "output_generated", 
                                                           "fname": fname}})
    connection.request("POST", "/api/v1/webhooks/st2", params, headers)
    
    response = connection.getresponse()
    data = response.read()

    connection.close()


def lambda_handler(event, context):
    # Get the object from the event and show its content type
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        print("CONTENT TYPE: " + response['ContentType'])

        # Tell StackStorm about the new file in the bucket
        # so that it can start the corresponding workflow
        st2_callback(key)

        return key


    except Exception as e:
        print(e)
        print('Error getting object {} from bucket {}. Make sure they exist and your bucket is in the same region as this function.'.format(key, bucket))
        raise e