mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir := $(dir $(mkfile_path))

message:
	@echo "This Makefile can be used for all of this projects setup/test/build/deploy."
	@echo "It requires the following utilities generally available i.e these will not be installed local to this project"
	@echo "cdk (globally install via npm install -g aws-cdk@1.126.0)"
	@echo "Then for base project setup do the idempotent 'make install'"

install:
	# setup the environment for the Python cdk IaC
	@pipenv install --dev

diff:
	@cdk diff

deploy: diff
	@cdk deploy --all
