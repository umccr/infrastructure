#!/bin/bash
set -e

################################################################################
# Script to fetch pipeline scripts from a specific GH commit 

repo="https://github.com/umccr/infrastructure"
timestamp="$(date +'%Y%m%d-%H%M%S')"

# TODO: the parameter(s) should be checked!
if [ $# -eq 0 ]; then
    echo "no args"
    commit="$(git ls-remote $repo refs/heads/master | cut -f 1)"
else
    echo "with args"
    commit="$1"
fi

echo "Creating log backups..."
shopt -s nullglob
for filename in *.log; do
  mv "$filename" "./log-archive/${filename}.$timestamp"
done

echo "Fetching scripts for commit: $commit"
/opt/gruntworks/fetch --repo $repo --commit $commit --source-path scripts/umccr_pipeline .
chmod 755 *.sh
echo "$timestamp Updated scripts to commit: $commit" >> version-log.txt
echo "Scripts updated."