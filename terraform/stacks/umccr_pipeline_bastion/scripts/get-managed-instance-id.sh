#!/bin/bash

#TODO: tidy up, make more generic and add error handling,...

instance_id=$(aws ssm describe-instance-information --cli-input-json '{"Filters":[{"Key":"tag:ServerName","Values":["novastor"]}]}' | jq '.InstanceInformationList[0].InstanceId')

echo "{\"instance_id\": $instance_id}"
