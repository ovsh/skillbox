# DESIGN.md — Loadout landing page ("Balance Patch" world)

Scope: `site/` (the landing page) and the Loadout brand mark. The **app's**
incumbent design system is separate and lives in `design/DIRECTION-A.md`
("Graphite"); nothing here restyles the app.

## World

Game balance-patch notes, played straight: the page is a patch dispatch for
your agents. Chosen 2026-07-23 via the impeccable direction roll (seed key
f7b02b17, assigned index 6 of the loadout-world derivation; user confirmed).
Explicitly refused: the dark-gradient dev-tool hero (category rut), and the
sibling PowerWatch pixel-sky "Daylight" world.

## Tokens

Ground (dispatch document, light — the near-black app screenshots are the
dark objects on it):

- `--bone: #F4F2EC` page ground · `--sheet: #FBFAF7` raised panels
- `--ink: #17181A` · `--mute: #5D6167` · `--faint: #9A9DA2`
- `--hairline: rgba(23,24,26,.14)` · heavy section rules 3px solid ink
- Diff inks (state semantics, the only saturated color):
  `--buff: #2E7D46` (equipped/+) · `--nerf: #BE4934` (benched/−)
  `--deploy: #C2593A` (primary action; matches the app's light-mode accent)
- App-window frames: `#101012` (Graphite canvas), hairline `rgba(255,255,255,.08)`

## Type

- Display: **Archivo** (variable, incl. Expanded/Black) — masthead version
  numerals, section headers as patch-section titles. Small-caps tracked
  labels for section kickers.
- Body: Archivo regular, 16–17px/1.6.
- Metadata/paths/deltas: `ui-monospace` stack, tabular numerals.
- Self-hosted WOFF2 in `site/assets/fonts/` (no third-party requests).

## Grammar (the patch-notes system carried into the page)

- Masthead: LOADOUT wordmark, a headline that states the offer in plain
  words ("Every skill your AI tools have, one switch each."), version + date
  in mono metadata, one supporting sentence, Download button. The patch
  grammar is visual (rules, markers, inks); the words never cosplay.
  Revised 2026-07-24 after user feedback plus a three-round blind visitor
  test loop (all PASS).
- Features are change entries: `+` buff rows in green, each with a one-line
  dev-note. Safety posture = "developer commentary" blockquotes.
- Real screenshots sit as embedded client windows: Graphite-dark, hairline
  border. The icon's corner brackets mark one equipped element per viewport:
  the hero's menu-bar callout, and the library client frame. Smaller shots
  (popover, bulk) stay plain so the bracket keeps its meaning.
- Trust/facts in tables with mono values. No badges, no gradients on ground.
- Bracket motif: HUD corner brackets (from the app icon) mark equipped
  things; never decorate more than one element per viewport with them.

## Motion (one narrative: the patch applies)

- Masthead version rolls up once on load (0.4.0 → 0.5.0 odometer, ~600ms,
  expo ease). Respect `prefers-reduced-motion`: render final state.
- Scroll: change entries enter with their diff marker ticking in and a
  green hairline sweep. Transform/opacity only; no blur filters on
  ambient layers, no `will-change` unless measured.
- No scattered hover wiggles. Buttery UI ease (expo), never pixel steps.

## Copy

Unslop voice: plain, factual, no AI cadence, no em dashes, value-first
headings. No invented numbers, testimonials, or claims. Estimates labeled.
Until the GitHub release exists, the Download button carries a marked
placeholder (`<!-- REPLACE -->`) and honest visible copy.

## Mood-board extraction (sources)

- recent.design grid, observed 2026-07-23: physical label/tag artifacts as
  graphic devices (stamp sheets, garment hang-tags with oversized numerals,
  sticker clusters); oversize editorial numerals with small scattered mono
  metadata chips; confirmed rut: near-black + centered display + gradient.
- Game patch-notes tradition (model knowledge, labeled as such): version
  numeral masthead, buff/nerf color semantics, dev-commentary blockquotes,
  grouped change lists.

## App brand carryover

- Icon: graphite tile, 2×2 HUD slot grid, one slot equipped in green
  (`design/brand/loadout-icon.svg` → `Sources/Loadout/Resources/AppIcon.png`).
- Menu bar glyph: SF Symbol `backpack`.
- The site's green/terracotta are the app's own state colors, darkened for
  light-ground contrast. Continuity is deliberate: state colors ARE the brand.
