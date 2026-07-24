#!/bin/bash
# Sign + notarize Loadout release artifacts with the Digital Lane LLC
# Developer ID.
#
#   sign-notarize.sh v0.5.0                  package, sign, notarize, staple, verify, dmg+zip
#   sign-notarize.sh v0.5.0 --skip-notarize  sign + verify signature only (no Apple round-trip)
#
# One-time prerequisite for notarization (must be done by a human, needs an
# app-specific password):
#   xcrun notarytool store-credentials digital-lane --apple-id <email> --team-id 7Z82LSPAPP
set -euo pipefail

IDENTITY="Developer ID Application: Digital Lane LLC (7Z82LSPAPP)"
PROFILE="${NOTARY_PROFILE:-digital-lane}"
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/Loadout.app"
DMG="$DIST/Loadout-MacOS.dmg"
ZIP="$DIST/Loadout-MacOS.zip"

VERSION_TAG="${1:-}"
[[ "$VERSION_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Usage: $0 vX.Y.Z [--skip-notarize]" >&2; exit 1; }
VERSION="${VERSION_TAG#v}"
SKIP_NOTARIZE=0
[[ "${2:-}" == "--skip-notarize" ]] && SKIP_NOTARIZE=1

fail() { echo "x $*" >&2; exit 1; }

security find-identity -v -p codesigning | grep -q "7Z82LSPAPP" \
  || fail "Developer ID cert for team 7Z82LSPAPP not in keychain. See SKILL.md, Troubleshooting."

if [[ $SKIP_NOTARIZE -eq 0 ]]; then
  xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 || fail \
"notarytool profile '$PROFILE' not found. A human must create it (needs an
app-specific password from https://account.apple.com):
    xcrun notarytool store-credentials $PROFILE --apple-id <email> --team-id 7Z82LSPAPP
Or re-run with --skip-notarize to sign only."
fi

echo ">> packaging + signing Loadout.app (package_app.sh notarizes the app when enabled)..."
if [[ $SKIP_NOTARIZE -eq 1 ]]; then
  VERSION="$VERSION" SKIP_NOTARIZE=1 "$ROOT/scripts/package_app.sh"
else
  VERSION="$VERSION" NOTARIZE_PROFILE="$PROFILE" "$ROOT/scripts/package_app.sh"
  echo ">> stapling Loadout.app..."
  xcrun stapler staple "$APP" || echo "warning: app stapling failed; Gatekeeper can still verify online"
fi

echo ">> creating DMG..."
"$ROOT/scripts/create_dmg.sh" "$APP" "$DMG"

echo ">> signing DMG..."
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

if [[ $SKIP_NOTARIZE -eq 0 ]]; then
  echo ">> notarizing DMG (this waits on Apple)..."
  xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
  echo ">> stapling DMG..."
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
fi

echo ">> zipping app (after stapling, so the ticket ships)..."
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo ">> verifying..."
codesign --verify --strict --deep "$APP"
codesign --verify "$DMG"
if [[ $SKIP_NOTARIZE -eq 0 ]]; then
  # Gatekeeper's verdict can lag stapling by a few seconds; retry briefly.
  ok=0
  for _ in 1 2 3 4 5; do
    if spctl -a -vv "$APP" 2>&1 | grep -q "Notarized Developer ID"; then ok=1; break; fi
    sleep 5
  done
  [[ $ok -eq 1 ]] || fail "spctl did not report Notarized Developer ID for $APP"
fi

echo "done: $DMG"
echo "      $ZIP"
