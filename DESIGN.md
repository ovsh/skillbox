# DESIGN.md — Loadout landing page ("Instrument" world)

Scope: `site/` (the landing page). The **app's** incumbent design system is
separate and lives in `design/DIRECTION-A.md` ("Graphite"); nothing here
restyles the app.

## World

The conventional modern Mac-app landing page, played straight, at Raycast's
craft bar. Chosen by the user as a standing preference (2026-07-24, recorded
in PRODUCT.md under Brand Commitments) after the themed "Balance Patch"
patch-notes world shipped and was rejected ("doesn't feel like a normal
landing page"). This is the canon executed at full fidelity: dark instrument
ground, one huge hero statement, quiet paired section headers, real product
windows carrying every section, hairline cards, one glowing off-white CTA.
No themed conceits, no pixel art, no patch-notes grammar.

Reference studied in the browser 2026-07-24: raycast.com. Its grammar, not
its skin: ground #07080A, one 64px/600 hero statement then 20px/500 header
pairs (white line + muted second line), hairline cards rgba(255,255,255,.08)
at 12–19px radius, ~1200px column, off-white buttons with layered ring
shadows, product UI as the only imagery.

## Tokens (settled by the build)

- Ground `--bg: #0A0B0D` · raised `--panel: #111216` · the app's Graphite
  canvas (#101012) arrives inside the screenshots and reads as kin
- Text `--fg: #F2F3F5` · secondary `--mute: #9BA0A6` · tertiary `--dim: #6C7076`
- Hairline `--line: rgba(255,255,255,.08)` · hover line `rgba(255,255,255,.16)`
- Accent `--green: #6CAB82` (the app icon's equipped-slot green; state color
  as brand). Small-text tint `#8FC4A4`. Used for: status dots, the toggle
  demo, inline emphasis. Never floods a region; the page is Restrained
  (neutrals + one accent).
- CTA is NOT the accent: off-white `#E9EAEC` button, near-black text,
  layered ring + soft glow shadow (the Raycast move). Green stays a state
  color.
- Radius: buttons 10px, cards 14px, window frames 12px. Borders 1px always.

## Type

- One face: **Archivo** variable (self-hosted WOFF2, weight 100–900, width
  62–125%), used at normal width throughout. The expanded-width display
  styling belonged to the rejected world; the canon wants it plain.
- Hero: clamp(40px → 68px), weight ~640, tracking -0.03em, line-height 1.03.
- Section header pairs: 21px/560 white + same-size muted second line.
- Body 16.5px/1.65. Small meta 13px.
- Mono (`ui-monospace` stack) only for code, paths, and values: the
  settings.json snippet, shelf paths, version numbers. Never as costume.

## Composition rules

- Content column 1152px; sections separated by 120–160px of ground on
  desktop (compressed to ~110–136px under 920px), no full-width tint bands,
  no section rules, no tracked-uppercase eyebrows.
- Screenshots are the imagery. Every window shot: 12px radius, 1px hairline,
  deep offset shadow (0 24px 80px rgba(0,0,0,.55)), never a glow halo.
- Nav: fixed pill, backdrop-blur, hairline border, app icon + wordmark left,
  anchor links + Download right; darkens and lifts a shadow once the page
  scrolls (`.scrolled`).
- Footer: brand + one-line description, two real-link groups (Product,
  Project), then a base row carrying the rename note ("Formerly Skillbox;
  the GitHub repo keeps the old name") and macOS 14+. No invented links.
- Mechanism panels are typographic evidence (real JSON, real paths), never
  fake UI. A real prompt-editor capture is excluded deliberately: it would
  publish the user's private CLAUDE.md contents.
- How-it-works is rows (text beside artifact), not icon cards. Each
  mechanism ships its evidence: real JSON, real paths, real UI.
- Trust is a definition-style list with mono values; every claim concrete
  and sourced from PRODUCT.md/README.md. Networking disclosure included.

## Motion (one authored system)

- Load: hero children rise 14px + fade, 80ms stagger, 700ms expo-out; the
  hero window settles from scale(.985). Scroll: each section reveals once,
  rise + fade only, threshold ~.18. Everything visible by default when
  `prefers-reduced-motion: reduce`. No blur filters on ambient layers.
- Signature interaction: the how-it-works toggle demo. A real switch flips
  skill `architect` between on and off and the settings.json snippet edits
  itself (the `"architect": "off"` line appears; restoring removes the
  entry, mirroring setOverride(nil) = restore default). Demonstrates the
  sanctioned mechanism, invents nothing.
- Hovers: buttons brighten, card borders lift. No wiggles.

## Copy

Unslop voice everywhere including `<title>`: plain, factual, no AI cadence,
no em dashes, sentence case headings. No invented numbers, testimonials, or
claims. The four real value strings (`on`, `name-only`,
`user-invocable-only`, `off`) and real paths
(`~/.claude/settings.json.loadout.bak`,
`~/Library/Application Support/Loadout/shelf/<tool>/`) are the proof
vocabulary.

## Assets

- Real captures only, in `site/assets/`: library.png (hero), popover.png +
  menubar.png (menu-bar section), bulk.png (trust visual), appicon.png.
- Fonts self-hosted; zero third-party requests from the page itself.

## App brand carryover

- Icon: graphite tile, corner-bracket slot grid, one slot equipped in green
  (`design/brand/loadout-icon.svg` → `Sources/Loadout/Resources/AppIcon.png`).
- Menu bar glyph: SF Symbol `backpack`.
- The page's green is the app's own equipped-state green. Continuity is
  deliberate: state color IS the brand. Terracotta stays inside the app.
