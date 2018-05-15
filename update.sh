#!/usr/bin/env sh
set -eu

# https://github.com/monostable/kicad_footprints/blob/master/update

max_parallel_tasks=10

#prevents git from waiting for password input on invalid/removed git URLs
export GIT_ASKPASS=/bin/echo

git submodule | awk '{ print $2 }' | xargs -I'{}' -P$max_parallel_tasks sh check.sh {}
