# Multi-account slack lambda

Handles Slack notifications while AWS Chatbot ups its game a bit more.

- Setup Python
```
conda create -n slack-infra python=3.11
conda activate slack-infra
pip install -r requirements.txt
```

- Setup CDK
- NOTE: We use _localised_ and _pinned_ CDK CLI as follows.
```
npm install
npx cdk --version
```

- Run CDK
```
npx cdk list
    batch-slack-lambda-dev
    batch-slack-lambda-prod
    batch-slack-lambda-stg

npx cdk synth

export AWS_PROFILE=dev && npx cdk diff batch-slack-lambda-dev
export AWS_PROFILE=stg && npx cdk diff batch-slack-lambda-stg
export AWS_PROFILE=prod && npx cdk diff batch-slack-lambda-prod

export AWS_PROFILE=dev && npx cdk deploy batch-slack-lambda-dev
export AWS_PROFILE=stg && npx cdk deploy batch-slack-lambda-stg
export AWS_PROFILE=prod && npx cdk deploy batch-slack-lambda-prod
```
