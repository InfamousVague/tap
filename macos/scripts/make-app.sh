#!/usr/bin/env bash
# Builds a release binary and assembles Tap.app — a menu-bar agent
# (LSUIElement, no Dock icon) with libTapPane + libSuiteKit in
# Contents/Frameworks and the TapWidgets.appex (built via Xcode at
# Widget/TapWidgets.xcodeproj) in Contents/PlugIns.
#
# Mirrors the build flow of alfred-swift / espresso-swift / etc.:
# inside-out codesign with hardened runtime, then `notarytool submit
# --wait` + `stapler staple`. The widget appex must be signed +
# embedded BEFORE the host app's signature is applied (the host's
# signature seals everything inside the bundle).
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="$ROOT/Tap.app"
SRC_ICON="$ROOT/art/AppIcon-source.png"
VERSION="2.1.5"
# Same Developer ID the rest of the suite uses. Override
# SIGN_IDENTITY=- for ad-hoc local-only builds (skips notarize).
SIGN_IDENTITY="${SIGN_IDENTITY:-0948896DC970503ADEF5B5070E0BB3E9D9047757}"
DMG="$ROOT/Tap-$VERSION.dmg"

echo "› swift build -c release"
swift build -c release
BIN="$(swift build -c release --show-bin-path)"

echo "› assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# App icon (optional — if art/AppIcon-source.png is absent we ship
# without a custom icon; the menu-bar glyph still shows up regardless).
ICON_KEY=""
if [ -f "$SRC_ICON" ]; then
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for spec in "16:16x16" "32:16x16@2x" "32:32x32" "64:32x32@2x" \
              "128:128x128" "256:128x128@2x" "256:256x256" "512:256x256@2x" \
              "512:512x512" "1024:512x512@2x"; do
    px="${spec%%:*}"; name="${spec##*:}"
    sips -z "$px" "$px" "$SRC_ICON" --out "$ICONSET/icon_${name}.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  ICON_KEY="  <key>CFBundleIconFile</key><string>AppIcon</string>"
else
  echo "⚠ no art/AppIcon-source.png — building without a custom app icon"
fi

# Host executable.
cp "$BIN/Tap" "$APP/Contents/MacOS/Tap"

# Embed + sign SuiteKit contract and Tap's pane dylib so the
# MattsSoftware launcher can dlopen the same code out of this
# installed .app. rpath lets the bundled exe find them under
# Contents/Frameworks at runtime.
mkdir -p "$APP/Contents/Frameworks"
cp "$BIN/libSuiteKit.dylib" "$APP/Contents/Frameworks/"
cp "$BIN/libTapPane.dylib" "$APP/Contents/Frameworks/"
if [ -d "$BIN/TapPane_TapPane.bundle" ]; then
  cp -R "$BIN/TapPane_TapPane.bundle" "$APP/Contents/Frameworks/"
fi
install_name_tool -add_rpath @executable_path/../Frameworks \
  "$APP/Contents/MacOS/Tap" 2>/dev/null || true

# ── Widget extension (.appex) ──────────────────────────────────────
# Built via Xcode (SR-14944: SwiftPM can't produce app-extension
# binaries). xcodegen regenerates the project from project.yml so the
# build is reproducible on a fresh checkout. SKIP_WIDGET=1 skips this
# step for fast host-only iteration.
if [ "${SKIP_WIDGET:-0}" != "1" ]; then
  if command -v xcodegen >/dev/null; then
    ( cd "$ROOT/Widget" && xcodegen generate --quiet )
  fi
  echo "› xcodebuild TapWidgets.appex"
  XCB_OUT="$ROOT/.build/xcode"
  xcodebuild \
    -project "$ROOT/Widget/TapWidgets.xcodeproj" \
    -scheme TapWidgets \
    -configuration Release \
    -derivedDataPath "$XCB_OUT" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$VERSION" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build >/dev/null
  APPEX_SRC="$XCB_OUT/Build/Products/Release/TapWidgets.appex"
  if [ -d "$APPEX_SRC" ]; then
    mkdir -p "$APP/Contents/PlugIns"
    cp -R "$APPEX_SRC" "$APP/Contents/PlugIns/TapWidgets.appex"
    echo "✓ embedded $APP/Contents/PlugIns/TapWidgets.appex"
  else
    echo "⚠ widget build produced no .appex — skipping embed"
  fi
fi

# Info.plist for the host. LSUIElement = true so we don't get a
# Dock icon (menu-bar agent only).
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Tap</string>
  <key>CFBundleDisplayName</key><string>Tap</string>
  <!-- Bundle id is `.macos` (not bare `.tap`) so the binary rides
       the existing developer-portal App ID at
       F6ZAL7ANAD.com.mattssoftware.tap.macos — which already has
       Sign in with Apple enabled and a Developer ID provisioning
       profile generated for it. The bare `.tap` id stays reserved
       for the iOS / watchOS companion apps. -->
  <key>CFBundleIdentifier</key><string>com.mattssoftware.tap.macos</string>
  <key>CFBundleExecutable</key><string>Tap</string>
$ICON_KEY
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Tap</string>
</dict>
</plist>
PLIST

# Developer ID provisioning profile — kept as a parameterised
# hook in case a future build needs to embed one. Currently
# unused: Sign in with Apple is the only entitlement that would
# benefit, and SIWA isn't supported on the Developer ID + non-
# Mac-App-Store path (see Tap.entitlements for the full
# investigation). Default empty = no profile embedded; pre-flight
# the right .provisionprofile via PROVISION_PROFILE_PATH if/when
# distribution moves to Mac App Store and SIWA becomes reachable.
PROVISION_PROFILE_PATH="${PROVISION_PROFILE_PATH:-}"
if [ -n "$PROVISION_PROFILE_PATH" ] && [ -f "$PROVISION_PROFILE_PATH" ]; then
  cp "$PROVISION_PROFILE_PATH" "$APP/Contents/embedded.provisionprofile"
  echo "✓ embedded provisioning profile from $PROVISION_PROFILE_PATH"
fi

# Inside-out codesign with hardened runtime. Sign in this exact
# order so each enclosing bundle re-seals correctly:
#   1. The embedded dylibs (SuiteKit + TapPane)
#   2. The widget appex binary, then its bundle
#   3. The host binary, then the host bundle
# Skip if no Developer ID is available — ad-hoc sign so the .app
# still runs locally for dev iteration.
HOST_ENT="$ROOT/Tap.entitlements"
WIDGET_ENT="$ROOT/Widget/Supporting Files/TapWidgets.entitlements"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
  codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$APP/Contents/Frameworks/libSuiteKit.dylib"
  codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$APP/Contents/Frameworks/libTapPane.dylib"
  if [ -d "$APP/Contents/PlugIns/TapWidgets.appex" ]; then
    codesign --force --options runtime --timestamp \
      --entitlements "$WIDGET_ENT" \
      --sign "$SIGN_IDENTITY" \
      "$APP/Contents/PlugIns/TapWidgets.appex/Contents/MacOS/TapWidgets"
    codesign --force --options runtime --timestamp \
      --entitlements "$WIDGET_ENT" \
      --sign "$SIGN_IDENTITY" \
      "$APP/Contents/PlugIns/TapWidgets.appex"
  fi
  codesign --force --options runtime --timestamp \
    --entitlements "$HOST_ENT" \
    --sign "$SIGN_IDENTITY" "$APP/Contents/MacOS/Tap"
  codesign --force --options runtime --timestamp \
    --entitlements "$HOST_ENT" \
    --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --strict --verbose=1 "$APP" \
    && echo "✓ signed: $SIGN_IDENTITY"
else
  echo "⚠ signing identity not found — ad-hoc signing instead"
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
fi
echo "✓ built $APP"

# ── Notarize + staple (Developer ID builds only) ─────────────────
# Runs BEFORE the .dmg is built so the disk image wraps an already-
# stapled app. We notarize the zipped app so the ticket rides on the
# .app; the .dmg is signed but not stapled (its first mount does a
# one-time online Gatekeeper check, which is fine for a freshly
# downloaded installer). Non-fatal: a creds-less or rejected build
# still completes — just signed, not notarized.
NOTARY_PROFILE="${NOTARY_PROFILE:-Notary}"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
  echo "› notarizing $APP (waits on Apple)…"
  NZIP="$(mktemp -d)/notarize.zip"
  ditto -c -k --keepParent "$APP" "$NZIP"
  if xcrun notarytool submit "$NZIP" \
       --keychain-profile "$NOTARY_PROFILE" --wait; then
    if xcrun stapler staple "$APP"; then
      if xcrun stapler validate "$APP"; then
        echo "✓ notarized + stapled $APP"
      else
        echo "⚠ staple validate failed for $APP"
      fi
    else
      echo "⚠ stapling failed for $APP"
    fi
  else
    echo "⚠ notarization skipped/failed — $APP signed but not notarized"
  fi
fi

# Optional .dmg from the now-stapled Tap.app.
if [ "${SKIP_DMG:-0}" != "1" ]; then
  STAGE="$(mktemp -d)/dmg"
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/Tap.app"
  ln -s /Applications "$STAGE/Applications"
  rm -f "$DMG"
  hdiutil create -quiet -volname "Tap" -srcfolder "$STAGE" \
    -ov -format UDZO "$DMG"
  if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
    codesign --force --sign "$SIGN_IDENTITY" "$DMG" || true
  fi
  echo "✓ built $DMG"
fi
