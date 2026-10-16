#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_tmp=$(mktemp -d)
trap 'rm -rf "$task_tmp"' EXIT
xcrun clang -fobjc-arc -framework Foundation -I ios/Sources/WristbandVendor/include ios/Tests/PolicyTests.m ios/Sources/WristbandVendor/WBPolicy.m -o "$task_tmp/policy-tests"
"$task_tmp/policy-tests"
