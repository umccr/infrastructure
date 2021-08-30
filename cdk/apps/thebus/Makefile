build:
	sam-beta-cdk build
deploy: build
	cdk deploy -a .aws-sam/build --profile ${AWS_PROFILE}
run:
	sam-beta-cdk local invoke
