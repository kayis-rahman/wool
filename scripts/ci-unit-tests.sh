#!/bin/bash
# Runs the iOS unit tests on a dedicated, freshly created simulator so CI never
# shares (or inherits a wedged) device with other jobs on the self-hosted runner.
# Usage: scripts/ci-unit-tests.sh create|test|cleanup
set -euo pipefail

DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro"
DEVICE_PREFIX="wool-ci"
DEVICE_NAME="${DEVICE_PREFIX}-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-0}"
STATE_FILE="${RUNNER_TEMP:-/tmp}/${DEVICE_NAME}.udid"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PWD/derived-data}"
MAX_ATTEMPTS=2

create() {
    # Remove devices leaked by earlier crashed or cancelled runs. Only the
    # wool-ci-* devices this script creates are touched.
    xcrun simctl list devices | awk -v p="$DEVICE_PREFIX-" 'index($0, p) { match($0, /[A-F0-9-]{36}/); if (RSTART) print substr($0, RSTART, RLENGTH) }' |
        while read -r stale; do
            xcrun simctl shutdown "$stale" 2>/dev/null || true
            xcrun simctl delete "$stale" 2>/dev/null || true
        done

    local udid
    udid="$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE")"
    echo "$udid" > "$STATE_FILE"
    echo "Created $DEVICE_NAME ($udid)"
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b
}

run_tests() {
    local udid="$1" log="$2"
    set +e
    xcodebuild test \
        -project apple/Wool/Wool.xcodeproj \
        -scheme "Wool iOS Unit Tests" \
        -destination "platform=iOS Simulator,id=${udid}" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -enableCodeCoverage NO 2>&1 | tee "$log"
    local status=${PIPESTATUS[0]}
    set -e
    return "$status"
}

test_run() {
    local udid log attempt
    udid="$(cat "$STATE_FILE")"
    log="${RUNNER_TEMP:-/tmp}/${DEVICE_NAME}.xcodebuild.log"
    for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
        if run_tests "$udid" "$log"; then
            return 0
        fi
        # Retry only the known simulator hang, never real test failures.
        if [ "$attempt" -lt "$MAX_ATTEMPTS" ] && grep -q "test runner hung before establishing connection" "$log"; then
            echo "Test runner hung (attempt $attempt/$MAX_ATTEMPTS); resetting simulator and retrying."
            xcrun simctl shutdown "$udid" || true
            xcrun simctl erase "$udid"
            xcrun simctl boot "$udid"
            xcrun simctl bootstatus "$udid" -b
            continue
        fi
        return 1
    done
}

cleanup() {
    [ -f "$STATE_FILE" ] || exit 0
    local udid
    udid="$(cat "$STATE_FILE")"
    xcrun simctl shutdown "$udid" 2>/dev/null || true
    xcrun simctl delete "$udid" 2>/dev/null || true
    rm -f "$STATE_FILE"
}

case "${1:-}" in
    create) create ;;
    test) test_run ;;
    cleanup) cleanup ;;
    *) echo "Usage: $0 create|test|cleanup" >&2; exit 2 ;;
esac
