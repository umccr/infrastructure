import os
import json
import http.client
from urllib import parse, request
import boto3

s3 = boto3.client('s3')
sqs = boto3.resource('sqs', region_name='ap-southeast-2')

st2_host = os.environ.get("ST2_HOST")
st2_url = os.environ.get("ST2_API_URL")
st2_api_token = os.environ.get("ST2_API_KEY")
queue_name = os.environ.get("QUEUE_NAME")

headers = {
    'St2-Api-Key': st2_api_token,
    'Content-Type': 'application/json',
}

def st2_callback(fname):
    """ Just a HTTP POST query to StackStorm server with minimal payload
    """
    
    connection = http.client.HTTPSConnection(st2_host)

    params = json.dumps({"trigger": "pcgr.up", "payload": {"status": "done", 
                                                           "task": "instantiate", 
                                                           "fname": fname}})
    connection.request("POST", "/api/v1/webhooks/st2", params, headers)
    
    # We do actually have to care about the response
    response = connection.getresponse()
    data = response.read()
    print(data)
    connection.close()

def queue_sample(fname):
    try:
        queue = sqs.get_queue_by_name(QueueName=queue_name)
    except:
        queue = sqs.create_queue(QueueName=queue_name, Attributes={'DelaySeconds': '5'})

    response = queue.send_message(MessageBody=fname)
    print(response)

def lambda_handler(event, context):
    print("Received event: " + json.dumps(event, indent=2))

    # Get the object from the event and show its content type
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        
        # Queue samples to be processed in AWS SQS Queue
        queue_sample(key)

        # Tell StackStorm about the new file in the bucket 
        # so that it can start the corresponding workflow
        st2_callback(key)
        
        return key


    except Exception as e:
        print(e)
        print('Error getting object {} from bucket {}. Make sure they exist and your bucket is in the same region as this function.'.format(key, bucket))
        raise e