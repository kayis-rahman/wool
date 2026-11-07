#!/bin/zsh
set -euo pipefail

PROJECT="apple/Wool/Wool.xcodeproj"
SCHEME="Wool iOS"
DEVICE_NAME="iPhone 18 Pro"
DERIVED_DATA="/private/tmp/wool-simulator-ui-tests"

usage() {
    print "Usage: ./scripts/run-on-simulator.sh [TEST_IDENTIFIER...]"
    print ""
    print "Builds the iOS UI-test bundle once, then runs each identifier without"
    print "rebuilding. Defaults to WoolUITests/WorkspaceUITests."
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

TEST_IDENTIFIERS=("${@:-WoolUITests/WorkspaceUITests}")
DEVICE_ID="$(xcrun simctl list devices available | awk -v name="$DEVICE_NAME" 'index($0, name " (") { match($0, /[A-F0-9-]{36}/); if (RSTART) { print substr($0, RSTART, RLENGTH); exit } }')"

if [[ -z "$DEVICE_ID" ]]; then
    print -u2 "No available $DEVICE_NAME simulator found."
    exit 2
fi

xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b
print "Using simulator: $DEVICE_NAME ($DEVICE_ID)"
print "Building once for ${#TEST_IDENTIFIERS[@]} UI test invocation(s)..."

xcodebuild -quiet build-for-testing \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$DEVICE_ID" \
    -derivedDataPath "$DERIVED_DATA" \
    -enableCodeCoverage NO

FAILED=()
for identifier in "${TEST_IDENTIFIERS[@]}"; do
    print "=== $identifier ==="
    if xcodebuild -quiet test-without-building \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,id=$DEVICE_ID" \
        -derivedDataPath "$DERIVED_DATA" \
        -only-testing:"$identifier" \
        -enableCodeCoverage NO; then
        print "$identifier PASS"
    else
        print "$identifier FAIL"
        FAILED+=("$identifier")
    fi
done

if (( ${#FAILED[@]} > 0 )); then
    print -u2 "Failed: ${FAILED[*]}"
    exit 1
fi

print "All ${#TEST_IDENTIFIERS[@]} simulator UI test invocation(s) passed."
