#!/bin/sh
# Cold-launches DuoTabs on a booted iPhone Duo simulator and prints the health check.
# Unfold the device in Device Hub first.
#
# usage: ./run.sh <simulator-udid>              stock order: rail tab bar missing
#        PREFRAME=1 ./run.sh <simulator-udid>   with tbc.view.frame = host.bounds before addSubview
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
UDID=${1:?usage: run.sh <simulator-udid>}
BUNDLE=dev.repro.duotabs
mkdir -p "$DIR/out"
xcrun simctl install "$UDID" "$DIR/build/DuoTabs.app"
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
sleep 1
SIMCTL_CHILD_PREFRAME=${PREFRAME:-0} xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
sleep 5
SHOT="$DIR/out/launch-preframe${PREFRAME:-0}-$(date +%H%M%S).jpg"
# Display 3 is the inner (unfolded) display. PNG screenshots of it come out black; JPEG works.
xcrun simctl io "$UDID" screenshot --type=jpeg --display=3 "$SHOT" >/dev/null 2>&1 || true
grep RESULT "$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)/Documents/log.txt"
echo "screenshot: $SHOT"
