This is a CDK repo deploying a lambda that takes in a presign URL and a prefix, runs Dracarys on the file downloaded from the presign URL, and writes the output to S3.

Ideally this CDK app should in addition do this:

1. Define step functions that guide the execution state of Dracarys.
