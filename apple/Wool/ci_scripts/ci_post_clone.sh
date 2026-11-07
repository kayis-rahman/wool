#!/bin/sh
set -e

if which swiftlint >/dev/null 2>&1; then
  cd "$CI_PRIMARY_REPOSITORY_PATH/apple/Wool"
  swiftlint --strict
else
  echo "swiftlint not installed on this Xcode Cloud image, skipping lint"
fi
