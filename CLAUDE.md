# Loadout — project notes for Claude

Menu-bar macOS skill manager for AI coding tools (formerly Skillbox; the
GitHub repo keeps the old slug `ovsh/skillbox`). Swift 6 SwiftPM: app target
`Loadout`, engine `LoadoutKit` (fully unit-tested). `swift build && swift
test` green is the gate. See README.md for the tour, PRODUCT.md for product
truth, DESIGN.md for the app's design system.

## Design work — use the design-motion skill

Any visual work (site/, app icon, brand) goes through the `design-motion`
skill's sequence: `/impeccable shape` with a user-confirmed content brief
BEFORE any visual direction, real product screenshots (never CSS depictions)
on marketing surfaces, and the impeccable-finish-reviewer before anything is
called done.

Two design docs, two scopes. **DESIGN.md** (root) is the app's design system —
the warm-graphite instrument world that replaced "Graphite" in the 2026-07-25
redesign; `design/DIRECTION-A.md` and `design/directions.html` are the
superseded predecessor, kept as anti-reference only. **design/LANDING.md** is
the landing page's world (single viewport, canonical Mac-app page).

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
