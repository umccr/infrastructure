#!/bin/bash
set -e
cd /Users/freisinger/UMCCR/infrastructure/terraform/stacks/gruntwork_houston/.terraform/modules/8aad252f6e4beee6aa9876f33ed5be73/modules/houston/web-content
rm -rf /Users/freisinger/UMCCR/infrastructure/terraform/stacks/gruntwork_houston/.terraform/modules/8aad252f6e4beee6aa9876f33ed5be73/modules/houston/web-content/rendered || true
mkdir -p rendered/houston-cli
cd /Users/freisinger/UMCCR/infrastructure/terraform/stacks/gruntwork_houston/.terraform/modules/8aad252f6e4beee6aa9876f33ed5be73/modules/houston/web-content/rendered
cp -R /Users/freisinger/UMCCR/infrastructure/terraform/stacks/gruntwork_houston/.terraform/modules/8aad252f6e4beee6aa9876f33ed5be73/modules/houston/web-content/template/* .
unamestr=`uname`
if [[ "$unamestr" == 'Darwin' ]]; then
  find . -type f \( -name "*.css" \) -print -exec sed -i '' 's~/REPLACEME~https://houston-static.umccr.org~g' {} \;
  find . -type f \( -name "*.js" -or -name "*.css" -or -name "*.html" \) -print -exec sed -i '' 's~REPLACEME~https://houston-static.umccr.org~g' {} \;
else
  find . -type f \( -name "*.css" \) -print -exec sed -i 's~/REPLACEME~https://houston-static.umccr.org~g' {} \;
  find . -type f \( -name "*.js" -or -name "*.css" -or -name "*.html" \) -print -exec sed -i 's~REPLACEME~https://houston-static.umccr.org~g' {} \;
fi

cd /Users/freisinger/UMCCR/infrastructure/terraform/stacks/gruntwork_houston/.terraform/modules/8aad252f6e4beee6aa9876f33ed5be73/modules/houston/web-content/rendered/houston-cli
cp -R /Users/freisinger/UMCCR/infrastructure/terraform/stacks/gruntwork_houston/.terraform/modules/8aad252f6e4beee6aa9876f33ed5be73/modules/houston/web-content/houston-cli/* .

cd /Users/freisinger/UMCCR/infrastructure/terraform/stacks/gruntwork_houston && s3_website push
rm -rf /Users/freisinger/UMCCR/infrastructure/terraform/stacks/gruntwork_houston/s3_website.yml
rm -rf /Users/freisinger/UMCCR/infrastructure/terraform/stacks/gruntwork_houston/.terraform/modules/8aad252f6e4beee6aa9876f33ed5be73/modules/houston/web-content/rendered || true
