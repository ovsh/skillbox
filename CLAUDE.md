# Loadout — project notes for Claude

Menu-bar macOS skill manager for AI coding tools (formerly Skillbox; the
GitHub repo keeps the old slug `ovsh/skillbox`). Swift 6 SwiftPM: app target
`Loadout`, engine `LoadoutKit` (fully unit-tested). `swift build && swift
test` green is the gate. See README.md for the tour, PRODUCT.md for product
truth, design/DIRECTION-A.md for the app's "Graphite" design system.

## Design work — use the design-motion skill

Any visual work (site/, app icon, brand) goes through the `design-motion`
skill's sequence: `/impeccable shape` with a user-confirmed content brief
BEFORE any visual direction, real product screenshots (never CSS depictions)
on marketing surfaces, and the impeccable-finish-reviewer before anything is
called done. The landing page's visual world ("Balance Patch") is recorded
in DESIGN.md; the app's incumbent system is design/DIRECTION-A.md.

The landing page's source of truth is `site/` here, but it DEPLOYS from the
personal-website repo (`~/Documents/code/personal-website/loadout/`, served
at ovsh.github.io/loadout/ — one deploy for the whole personal site). After
any site/ change, run `scripts/sync-site.sh` and commit both repos.

## Signing & notarization — use the apple-sign skill

Use `.claude/skills/apple-sign/` for anything involving codesigning,
notarization, stapling, Gatekeeper, or preparing a release. Developer ID
"Digital Lane LLC" (team `7Z82LSPAPP`), notarytool keychain profile
`digital-lane`. Never handle the user's Apple ID password; the
`store-credentials` step is user-only. `scripts/package_app.sh` signs and
notarizes when run without SKIP_NOTARIZE; ad-hoc local builds use
`CODESIGN_IDENTITY="-" SKIP_NOTARIZE=1`.
