mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir := $(dir $(mkfile_path))

message:
	@echo "This Makefile can be used for all of this projects setup/test/build/deploy."
	@echo "It requires the following utilities generally available i.e these will not be installed local to this project"
	@echo "cdk (globally install via npm install -g aws-cdk@next)"
	@echo "pipenv (brew install pipenv)"
	@echo "Then for base project setup do the idempotent 'make install'"

install:
	# setup the environment for the Python cdk IaC
	@pipenv install --dev
	# make sure the requirements.txt is up to date for any lambdas
	@pipenv run pip-compile --quiet --generate-hashes lambdas/ppauthz/requirements.in
	# make the lambda packages available in the outer pipenv (just for pycharm/dev purposes)
	@pipenv run pip install -r "lambdas/ppauthz/requirements.txt"

test:
	@(cd lambdas/ppauthz && pipenv run python3 -m unittest)

diff:
	@cdk diff

deploy: diff
	@cdk deploy --all

# runs a htsget server the same as would be run in ECS - but locally with the repos localhost.json config
# we pass in any environment AWS credentials so we can test it doing S3 operations etc
localhtsget:
	docker container run --rm -p 3000:3000 \
			-e AWS_ACCESS_KEY_ID \
            -e AWS_DEFAULT_REGION \
            -e AWS_REGION \
            -e AWS_ROLE_SESSION_NAME \
            -e AWS_SECRET_ACCESS_KEY \
            -e AWS_SESSION_TOKEN \
            -e AWS_SHARED_CREDENTIALS_FILE \
            -e AWS_STS_REGIONAL_ENDPOINTS \
            -v "$(mkfile_dir)config:/usr/src/app/config" \
            "ga4gh/htsget-refserver:1.5.0" ./htsget-refserver -config /usr/src/app/config/localhost.json
