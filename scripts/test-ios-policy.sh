#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_tmp=$(mktemp -d)
trap 'rm -rf "$task_tmp"' EXIT
for suite in PolicyTests HistoryMappingTests; do
    xcrun clang -fobjc-arc -framework Foundation -I ios/Sources/WristbandVendor/include "ios/Tests/$suite.m" ios/Sources/WristbandVendor/WBPolicy.m -o "$task_tmp/$suite"
    "$task_tmp/$suite"
done
