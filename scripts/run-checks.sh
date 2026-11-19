#!/usr/bin/env bash
# Run the offline checks against production Swift sources on a Mac with Xcode.
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"

python3 scripts/check-localization.py
python3 scripts/test-localization.py

if ! command -v xcrun >/dev/null 2>&1; then
    echo "Swift/MapKit checks require macOS and Xcode (xcrun)." >&2
    exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/wrappin-checks.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

swift_check() {
    local name="$1"
    shift
    echo "== $name =="
    xcrun swiftc -parse-as-library -module-cache-path "$WORK/cache" \
        "scripts/$name.swift" "$@" -o "$WORK/$name"
    "$WORK/$name"
}

swift_check test-localization-bundle
swift_check check-fixed-coordinate-mode \
    WrapPin/Services/FixedCoordinateMode.swift WrapPin/Models/LocationTarget.swift \
    WrapPin/Models/SessionRecoveryRecord.swift WrapPin/Models/CoordinateModeMemory.swift
swift_check test-coordinate-input WrapPin/Features/Map/CoordinateInputParser.swift
swift_check test-route-recovery WrapPin/Models/SessionRecoveryRecord.swift
swift_check test-session-recovery-policy \
    WrapPin/Services/FailureStage.swift WrapPin/Services/SessionRecoveryPolicy.swift \
    WrapPin/Models/SessionRecoveryRecord.swift
swift_check test-location-reconnect-policy \
    WrapPin/Services/LocationSessionReconnectPolicy.swift WrapPin/Services/FailureStage.swift
swift_check test-tunnel-handoff WrapPin/Models/AppPreferences.swift WrapPin/App/BuildEdition.swift
swift_check test-route-selection WrapPin/Features/Map/RouteHitTesting.swift
swift_check test-overseas-search WrapPin/Services/OverseasPlaceSearch.swift
swift_check test-pairing-import \
    WrapPin/Services/Pairing/PairingService.swift WrapPin/Services/Pairing/DevicePairingSupport.swift
swift_check test-custom-routes \
    WrapPin/Features/Map/RouteMode.swift WrapPin/Features/Map/WalkingRoutePlanner.swift \
    WrapPin/Features/Map/WalkingSimulationController.swift WrapPin/Features/Map/SimulationRoute.swift \
    WrapPin/Features/Map/GPXRouteParser.swift WrapPin/Features/Map/MapKitCompatibility.swift \
    WrapPin/Models/SessionRecoveryRecord.swift WrapPin/Services/FixedCoordinateMode.swift \
    WrapPin/Models/LocationTarget.swift
swift_check test-route-point-search \
    WrapPin/Features/Map/MapViewModel.swift WrapPin/Features/Map/MapKitCompatibility.swift \
    WrapPin/Features/Map/CoordinateInputParser.swift WrapPin/Features/Map/RouteWaypoint.swift \
    WrapPin/Models/LocationTarget.swift WrapPin/Services/OverseasPlaceSearch.swift \
    WrapPin/Features/Map/SimulationRoute.swift WrapPin/Features/Map/GPXRouteParser.swift

for check in scripts/test-*.py; do
    if [[ "$check" != scripts/test-localization.py ]]; then
        echo "== $check =="
        python3 "$check"
    fi
done

find WrapPin/Resources -name '*.strings' -print0 | xargs -0 plutil -lint
plutil -lint Configuration/WrapPin-Info.plist WrapPin/Resources/PrivacyInfo.xcprivacy
echo "All offline checks passed. Device pairing, route coverage and SideStore installation still need a physical iPhone."
