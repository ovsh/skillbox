---
name: apple-sign
description: Codesign and notarize Loadout's artifacts (Loadout.app and the release DMG/ZIP) with the Digital Lane LLC Developer ID certificate, then staple and verify with Gatekeeper. Use this whenever the user wants to sign, notarize, staple, release, or distribute the app; when Gatekeeper blocks it ("app is damaged", "cannot be opened because the developer cannot be verified", quarantine warnings); or after a local ad-hoc build that needs to become distributable.
---

# Apple Sign & Notarize (Digital Lane LLC)

Sign and notarize Loadout's release artifacts so they pass Gatekeeper on
other Macs:

- `dist/Loadout.app` — the menu bar app (bundle id `com.ovsh.loadout`)
- `dist/Loadout-MacOS.dmg` — the release disk image
- `dist/Loadout-MacOS.zip` — the release zip (also the self-update asset)

Certificate: `Developer ID Application: Digital Lane LLC (7Z82LSPAPP)`
(team ID `7Z82LSPAPP`). It must be in the login keychain — check with
`security find-identity -v -p codesigning`.

## The fast path

From the repo root:

```bash
.claude/skills/apple-sign/scripts/sign-notarize.sh v0.5.0
```

It builds and packages the app signed with the Developer ID (via
`scripts/package_app.sh`, which also notarizes the app bundle), creates the
DMG, signs and notarizes the DMG, staples both, verifies with `spctl` and
`stapler validate`, and leaves `Loadout-MacOS.dmg` + `Loadout-MacOS.zip` in
`dist/`. Pass `--skip-notarize` to sign only (enough for this Mac, not for
distribution).

## One-time setup: notary credentials (user must do this personally)

Notarization needs stored credentials under the keychain profile
`digital-lane`. If `xcrun notarytool history --keychain-profile digital-lane`
errors, the profile is missing. Do NOT attempt to create it yourself — it
requires the user's Apple ID app-specific password, which the agent must
never handle. Instead, ask the user to run:

```bash
xcrun notarytool store-credentials digital-lane \
  --apple-id <apple-id-email> --team-id 7Z82LSPAPP
```

They'll be prompted for an app-specific password (created at
https://account.apple.com → Sign-In and Security → App-Specific Passwords).
Once stored, the profile persists and this skill works unattended.

## What the flow does (if you need to run it manually)

1. **Package + sign the app**: `VERSION=<x.y.z> ./scripts/package_app.sh`
   with no CODESIGN_IDENTITY override signs with the Developer ID
   (hardened runtime) and submits the app to the notary service using the
   `digital-lane` profile, then staples.
2. **DMG**: `./scripts/create_dmg.sh` builds `dist/Loadout-MacOS.dmg` with
   the drag-to-Applications layout.
3. **Sign the DMG**:
   `codesign --force --timestamp --sign "Developer ID Application: Digital Lane LLC (7Z82LSPAPP)" dist/Loadout-MacOS.dmg`
4. **Notarize the DMG**:
   `xcrun notarytool submit dist/Loadout-MacOS.dmg --keychain-profile digital-lane --wait`
5. **Staple**: `xcrun stapler staple dist/Loadout-MacOS.dmg` (and the .app).
6. **Verify**: `spctl -a -vv dist/Loadout.app` must say
   `accepted · source=Notarized Developer ID`;
   `xcrun stapler validate dist/Loadout-MacOS.dmg`.
7. **Zip AFTER stapling**: `ditto -c -k --sequesterRsrc --keepParent
   dist/Loadout.app dist/Loadout-MacOS.zip` (zip before stapling loses the
   ticket).

## Troubleshooting

- **codesign hangs or errors with "User interaction is not allowed"**: the
  keychain wants approval to use the private key. The user must click
  "Always Allow" on the macOS prompt once; tell them to watch for the dialog.
- **notarytool "Invalid" status**: fetch the reason with
  `xcrun notarytool log <submission-id> --keychain-profile digital-lane`.
  Usual causes: missing `--options runtime`, missing `--timestamp`, or an
  unsigned nested binary.
- **spctl rejects after signing but before notarizing**: normal. Developer ID
  alone no longer satisfies Gatekeeper; notarization is mandatory.
- **Cert expired/revoked**: renew in the Apple Developer portal
  (Certificates → Developer ID Application), download, double-click to
  install, confirm with `security find-identity -v -p codesigning`.
