#!/bin/bash
# Driver for the nbledger iOS app in the iOS Simulator.
# Usage: .claude/skills/run-nbledger-ios/run.sh <command> [args]
#
# Commands:
#   doctor          Check toolchain prerequisites (scheme, platform, runtime match)
#   build           Build the app for the simulator
#   launch          Boot simulator, install + launch the app, open Simulator.app
#   shot [path]     Screenshot the booted simulator (default /tmp/nbledger.png)
#   ui-shots [dir]  Run the navigation UI test and export its screenshots
#                   (default /tmp/nbl_shots)
#   all             build + launch + shot

set -euo pipefail
cd "$(dirname "$0")/../../.."

BUNDLE_ID="com.nobleledger.nbl"
DD="build/dd"
APP="$DD/Build/Products/Debug-iphonesimulator/nbledger.app"

# Newest available iPhone simulator (last iPhone line of the last iOS section).
sim_id() {
  xcrun simctl list devices available \
    | grep -E "^\s+iPhone" \
    | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' \
    | tail -1
}

booted_id() {
  xcrun simctl list devices booted \
    | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' \
    | head -1
}

device() {
  local id
  id=$(booted_id)
  [ -n "$id" ] && { echo "$id"; return; }
  sim_id
}

cmd_doctor() {
  local ok=0

  if [ -f nbledger.xcodeproj/xcshareddata/xcschemes/nbledger.xcscheme ]; then
    echo "ok: shared scheme present"
  else
    echo "FAIL: no shared scheme — CLI builds will report 'supported platforms is empty'."
    echo "      Restore nbledger.xcodeproj/xcshareddata/xcschemes/nbledger.xcscheme from git."
    ok=1
  fi

  if xcodebuild -project nbledger.xcodeproj -scheme nbledger -showdestinations 2>/dev/null \
      | grep -q "platform:iOS Simulator"; then
    echo "ok: simulator destinations visible"
  else
    echo "FAIL: xcodebuild sees no simulator destinations."
    echo "      Usually the Xcode iOS platform is missing: run 'xcodebuild -downloadPlatform iOS' (~8.5 GB)."
    ok=1
  fi

  local sdk_build runtimes
  sdk_build=$(xcodebuild -showsdks 2>/dev/null | grep -o 'iphonesimulator[0-9.]*' | head -1 | sed 's/iphonesimulator//')
  echo "info: iphonesimulator SDK $sdk_build"
  if ! xcrun simctl list runtimes | grep -q "iOS $sdk_build"; then
    echo "warn: no simulator runtime matches SDK $sdk_build."
    echo "      Either 'xcodebuild -downloadPlatform iOS' or map the SDK to an installed runtime build:"
    echo "      xcrun simctl runtime match set iphoneos$sdk_build <installed-runtime-build>   # e.g. 23E254a"
    xcrun simctl runtime match list 2>/dev/null | grep -A 5 "iphoneos$sdk_build:" || true
  else
    echo "ok: runtime for SDK $sdk_build installed"
  fi

  exit $ok
}

cmd_build() {
  local id
  id=$(device)
  [ -n "$id" ] || { echo "no iPhone simulator found"; exit 1; }
  xcodebuild -project nbledger.xcodeproj -scheme nbledger \
    -destination "platform=iOS Simulator,id=$id" \
    -derivedDataPath "$DD" build
}

cmd_launch() {
  local id
  id=$(device)
  [ -n "$id" ] || { echo "no iPhone simulator found"; exit 1; }
  [ -d "$APP" ] || { echo "app not built — run '$0 build' first"; exit 1; }
  xcrun simctl boot "$id" 2>/dev/null || true
  xcrun simctl install "$id" "$APP"
  xcrun simctl launch "$id" "$BUNDLE_ID"
  open -a Simulator
  echo "launched $BUNDLE_ID on $id"
}

cmd_shot() {
  local out="${1:-/tmp/nbledger.png}" id
  id=$(booted_id)
  [ -n "$id" ] || { echo "no booted simulator"; exit 1; }
  xcrun simctl io "$id" screenshot "$out"
  echo "$out"
}

cmd_ui_shots() {
  local out="${1:-/tmp/nbl_shots}" id
  id=$(device)
  rm -rf build/uitest.xcresult "$out"
  mkdir -p "$out"
  xcodebuild -project nbledger.xcodeproj -scheme nbledger \
    -destination "platform=iOS Simulator,id=$id" \
    -derivedDataPath "$DD" -resultBundlePath build/uitest.xcresult \
    -only-testing:nbledgerUITests/ApprovalScreensScreenshotTests test \
    | grep -E "Test Case|TEST" || true
  xcrun xcresulttool export attachments --path build/uitest.xcresult --output-path "$out"
  echo "screenshots + manifest.json in $out"
}

case "${1:-}" in
  doctor)   cmd_doctor ;;
  build)    cmd_build ;;
  launch)   cmd_launch ;;
  shot)     shift; cmd_shot "$@" ;;
  ui-shots) shift; cmd_ui_shots "$@" ;;
  all)      cmd_build && cmd_launch && sleep 4 && cmd_shot ;;
  *)        sed -n '2,12p' "$0"; exit 1 ;;
esac
