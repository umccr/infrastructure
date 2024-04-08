EXECUTABLES = python3 uv npx
K := $(foreach exec,$(EXECUTABLES), $(if $(shell which $(exec)),some string,$(error "No $(exec) in PATH")))

#
# by default we do everything to set up for running any of the backends
#

all: setup-python-cdk

setup: setup-python-cdk

setup-python-cdk: .venv/install.touch

.PHONY: all build setup setup-python-cdk

#
# the actual targets that should be targeted for running the various cdk steps
#

deploy-cdk-dev: setup-python-cdk typecheck
	. .venv/bin/activate; npx --yes cdk deploy ica-credentials-dev/stack

undeploy-cdk-dev: setup-python-cdk typecheck
	. .venv/bin/activate; npx --yes cdk undeploy ica-credentials-dev/stack

typecheck:
	. .venv/bin/activate; mypy lambdas/notify_slack_lambda lambdas/jwt_producer_lambda

.PHONY: deploy-cdk undeploy-cdk typecheck

#
# clean up working folders
#

clean: clean-python-cdk

clean-python-cdk:
	find . -type f -name '*.py[co]' -delete -o -type d -name __pycache__ -delete
	rm -rf .venv/
	rm -rf cdk.out/

.PHONY: clean clean-python-cdk

# actual rules that create files/folders and build things

# track the existence of the virtual with the activate script - everything is essentially dependent on this
# NOTE: the python version chosen here should match that chosen for lambdas in the CDK!
.venv/bin/activate:
	uv venv -p 3.11

requirements.txt: requirements.in
	. .venv/bin/activate; uv pip compile requirements.in -o requirements.txt

requirements-dev.txt: requirements-dev.in
	. .venv/bin/activate; uv pip compile requirements-dev.in -o requirements-dev.txt

# track the actual time of pip install with a touch file - so that it will re-trigger on changes to requirements
.venv/install.touch: .venv/bin/activate requirements.txt requirements-dev.txt
	. .venv/bin/activate; uv pip install -r requirements.txt -r requirements-dev.txt && touch .venv/install.touch
