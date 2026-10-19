#!/bin/sh
# Builds DuoTabs.app for the iOS simulator from main.m (no Xcode project needed).
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
APP="$DIR/build/DuoTabs.app"
rm -rf "$APP"
mkdir -p "$APP"
xcrun -sdk iphonesimulator clang -fobjc-arc -O0 -g -target arm64-apple-ios26.1-simulator \
  -framework UIKit -framework Foundation -framework CoreGraphics -o "$APP/DuoTabs" "$DIR/main.m"
cp "$DIR/Info.plist" "$APP/Info.plist"
codesign -s - --force "$APP"
echo "built $APP"
