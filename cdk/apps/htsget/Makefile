install:
	@pip install -r requirements.txt

test:
	@(cd lambdas/ppauthz && python -m unittest)

diff:
	@cdk diff

deploy: diff
	@cdk deploy --all

refresh:
	@rm -rf lambdas/.build

refresh_deploy: refresh deploy
