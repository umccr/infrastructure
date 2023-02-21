#!/bin/sh

aws sqs send-message --region ap-southeast-2 --endpoint-url https://sqs.ap-southeast-2.amazonaws.com/ \
                                             --queue-url https://sqs.ap-southeast-2.amazonaws.com/843407916570/data-portal-dracarys-queue \
                                             --message-body "This is a Dracarys test" \
                                             --message-attributes file://test_queue_msg.json
