#!/bin/sh

aws sqs send-message --region ap-southeast-2 --endpoint-url https://sqs.ap-southeast-2.amazonaws.com/ \
                                             --queue-url https://sqs.ap-southeast-2.amazonaws.com/472057503814/data-portal-dracarys-queue \
                                             --message-body "Warehouse metadata import" \
                                             --message-attributes file://test_queue_msg.json
