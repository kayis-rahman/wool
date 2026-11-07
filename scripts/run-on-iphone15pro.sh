#!/bin/zsh
set -euo pipefail

PROJECT="apple/Wool/Wool.xcodeproj"
SCHEME="Wool iOS"
APP_BUNDLE_ID="com.sparkage.wool.ios"
BUILD_DERIVED_DATA="/private/tmp/wool-iphone15pro-derived"
TEST_DERIVED_DATA="/private/tmp/wool-iphone15pro-ui-tests"
SCRIPT_NAME="${0:t}"

usage() {
  print "Usage: ./$SCRIPT_NAME [--test [TEST_IDENTIFIER...]]"
  print "       ./$SCRIPT_NAME --test-each TEST_IDENTIFIER..."
  print ""
  print "Without arguments, builds, installs, and launches Wool."
  print ""
  print "--test [TEST_IDENTIFIER...]"
  print "  Runs physical-device UI tests in one xcodebuild invocation. Accepts one"
  print "  or more -only-testing identifiers as separate arguments. Defaults to:"
  print "    WoolUITests/WorkspaceUITests"
  print ""
  print "--test-each TEST_IDENTIFIER..."
  print "  Builds for testing once, then runs each given identifier as its own"
  print "  test-without-building invocation (one process launch per test, same"
  print "  build) and prints a PASS/FAIL summary line per test. Use this instead"
  print "  of looping --test yourself: it skips the xcodebuild rebuild check"
  print "  between tests, which is most of the per-test overhead when iterating"
  print "  one test at a time."
}

MODE="run"
TEST_IDENTIFIERS=("WoolUITests/WorkspaceUITests")
case "${1:-}" in
  "") ;;
  --test)
    MODE="test"
    if [[ $# -gt 1 ]]; then
      TEST_IDENTIFIERS=("${@:2}")
    fi
    ;;
  --test-each)
    if [[ $# -lt 2 ]]; then
      print -u2 "--test-each requires at least one TEST_IDENTIFIER."
      usage >&2
      exit 2
    fi
    MODE="test-each"
    TEST_IDENTIFIERS=("${@:2}")
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

# Resolve the currently available physical iPhone 15 Pro for the optional
# device workflow. Never retain a stale identifier.
DEVICE_LIST_OUTPUT="$(xcrun devicectl list devices 2>&1)" || {
  print -u2 "devicectl could not enumerate devices."
  print -u2 -- "$DEVICE_LIST_OUTPUT"
  print -u2 "Reconnect and unlock the iPhone, then rerun this command."
  exit 2
}

DEVICE_ID="$(print -r -- "$DEVICE_LIST_OUTPUT" \
  | grep -F 'available (paired)' \
  | grep -F 'iPhone 15 Pro' \
  | grep -Eo '([0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12})' \
  | head -n 1 || true)"
if [[ -z "$DEVICE_ID" ]]; then
  echo "No available paired physical iPhone 15 Pro found; stopping." >&2
  print -u2 -- "$DEVICE_LIST_OUTPUT"
  print -u2 "The phone must show: available (paired) ... iPhone 15 Pro ... physical"
  exit 2
fi
echo "Using physical iPhone 15 Pro: $DEVICE_ID"

# devicectl and xcodebuild maintain separate device-service state. Require both
# tools to recognize the same physical destination before building or testing.
DESTINATIONS_OUTPUT="$(xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -showdestinations 2>&1)" || {
  print -u2 "xcodebuild could not enumerate destinations."
  print -u2 -- "$DESTINATIONS_OUTPUT"
  exit 2
}

if ! print -r -- "$DESTINATIONS_OUTPUT" | grep -F "platform:iOS" | grep -Fq "id:$DEVICE_ID"; then
  print -u2 "devicectl sees the iPhone, but xcodebuild does not list it as an iOS destination."
  print -u2 "Reconnect and unlock the phone, run xcodebuild -runFirstLaunch, then retry."
  print -u2 "If automation reports 'Operation not permitted' under ~/Library, grant it access"
  print -u2 "to Xcode/CoreDevice services or run this script from an unrestricted Terminal."
  exit 2
fi

echo "Checking iPhone 15 Pro lock state..."
LOCK_STATE_OUTPUT=$(xcrun devicectl device info lockState --device "$DEVICE_ID" 2>&1) || {
  echo "Unable to query the iPhone through CoreDevice. Reconnect and unlock the device, then retry." >&2
  echo "$LOCK_STATE_OUTPUT" >&2
  exit 2
}

if ! print -r -- "$LOCK_STATE_OUTPUT" | rg -q 'passcodeRequired: false'; then
  echo "iPhone 15 Pro is locked. Unlock it and keep it awake before running this script." >&2
  exit 2
fi

if [[ "$MODE" == "test" ]]; then
  ONLY_TESTING_ARGS=()
  for id in "${TEST_IDENTIFIERS[@]}"; do
    ONLY_TESTING_ARGS+=("-only-testing:$id")
  done
  echo "Running ${TEST_IDENTIFIERS[*]} on the physical iPhone 15 Pro..."
  echo "Result bundles will be under $TEST_DERIVED_DATA/Logs/Test"
  xcodebuild -quiet test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS,id=$DEVICE_ID" \
    -derivedDataPath "$TEST_DERIVED_DATA" \
    -allowProvisioningUpdates \
    -enableCodeCoverage NO \
    "${ONLY_TESTING_ARGS[@]}" || {
      test_exit_code=$?
      print -u2 "Physical-device test failed. This is not a simulator result."
      print -u2 "Inspect $TEST_DERIVED_DATA/Logs/Test/*.xcresult with xcresulttool."
      print -u2 "If output contains 'Operation not permitted' for ~/Library or CoreSimulator,"
      print -u2 "the runner is sandboxed; allow Xcode/CoreDevice access and rerun."
      exit "$test_exit_code"
    }
  exit 0
fi

if [[ "$MODE" == "test-each" ]]; then
  echo "Building for testing once, then running ${#TEST_IDENTIFIERS[@]} tests without rebuilding..."
  echo "Result bundles will be under $TEST_DERIVED_DATA/Logs/Test"
  xcodebuild -quiet build-for-testing \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS,id=$DEVICE_ID" \
    -derivedDataPath "$TEST_DERIVED_DATA" \
    -allowProvisioningUpdates || {
      print -u2 "build-for-testing failed; see output above."
      exit 2
    }

  FAILED_TESTS=()
  for id in "${TEST_IDENTIFIERS[@]}"; do
    echo "=== $id ==="
    if xcodebuild -quiet test-without-building \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -destination "platform=iOS,id=$DEVICE_ID" \
      -derivedDataPath "$TEST_DERIVED_DATA" \
      -only-testing:"$id"; then
      echo "$id PASS"
    else
      echo "$id FAIL"
      FAILED_TESTS+=("$id")
    fi
  done

  echo ""
  echo "Result bundles are under $TEST_DERIVED_DATA/Logs/Test"
  if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
    print -u2 "Failed: ${FAILED_TESTS[*]}"
    exit 1
  fi
  echo "All ${#TEST_IDENTIFIERS[@]} tests passed."
  exit 0
fi

APP_PATH="$BUILD_DERIVED_DATA/Build/Products/Debug-iphoneos/Wool iOS.app"

xcodebuild -quiet build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath "$BUILD_DERIVED_DATA" \
  -allowProvisioningUpdates

xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
xcrun devicectl device process launch --device "$DEVICE_ID" \
  --terminate-existing "$APP_BUNDLE_ID"
