<!-- Scope: the site/ landing page only. The APP's design system is
     DESIGN.md at the repo root. This file was DESIGN.md on the
     claude/goofy-swartz-636c92 branch, before the app redesign took
     that filename for the product itself. -->

# DESIGN.md — Loadout landing page ("Instrument" world, single-viewport)

Scope: `site/` (the landing page). The **app's** incumbent design system is
separate and lives in `DESIGN.md` at the repo root; nothing here
restyles the app.

## World

The conventional modern Mac-app landing page, played straight, at Raycast's
craft bar — compressed to ONE VIEWPORT with no scrolling. Two user rulings
shape this surface (both 2026-07-24, recorded in PRODUCT.md Brand
Commitments):

1. No themed conceits. The "Balance Patch" patch-notes world was built and
   rejected ("doesn't feel like a normal landing page"). Pixel-art excluded.
2. No long-scroll page. The multi-section build (hero / menu-bar / three
   mechanism rows / trust / close) was rejected as "too convoluted". The
   page is a single screen: statement, one supporting sentence, Download,
   fact line, one real window. Mechanism detail lives in the GitHub README.

Reference studied in the browser 2026-07-24: raycast.com. Its grammar, not
its skin: near-black ground, one huge statement, off-white glowing CTA,
real product UI as the only imagery.

## Tokens

- Ground `--bg: #0A0B0D`; the app's Graphite canvas (#101012) arrives inside
  the screenshot and reads as kin.
- Text `--fg: #F2F3F5` · secondary `--mute: #9BA0A6` · tertiary `--dim: #6C7076`
- Hairline `--line: rgba(255,255,255,.08)` · window edge `rgba(255,255,255,.16)`
- CTA off-white `--cta: #E9EAEC`, text `#17181B`, layered ring + soft glow
  shadow (the Raycast move). Page chrome stays neutral; the green lives in
  the screenshot and in the ground atmosphere (below).
- Ground atmosphere (`.bg`, fixed, aria-hidden): a green radial bloom
  (rgba(108,171,130,.26) ellipse centered at the window's top edge) plus a
  deeper green wash from the bottom, a faint off-white spotlight over the
  statement, and SVG fractalNoise film grain at ~2% effective alpha. All
  CSS, zero requests, static (nothing animates). A tiled hairline grid was
  tried and cut (stock generated-UI signature, flagged by the design hook;
  glows-not-grids is also Raycast's own grammar).
- Radius: buttons 10px, window frame 12px. Borders 1px always.

## Type

- One face: **Archivo** variable (self-hosted WOFF2), normal width.
- Statement: clamp(40px → 72px), weight 640, tracking -0.03em, balanced.
- Supporting sentence: 15.5–17.5px (vh-clamped), `--mute`, max 68ch,
  two lines on desktop.
- Mono (`ui-monospace` stack) only for the fact line:
  "Free, MIT · Signed and notarized · macOS 14+", color #8A9098
  (6.1:1 on the ground — `--dim` fails AA at this size, `--mute` outshouts
  the sub).

## Composition (single viewport)

- `html, body { overflow: hidden }`; body is a 100% flex column:
  slim bar → centered hero column → window.
- Bar: brand (icon + wordmark) left, GitHub ↗ right. No nav links; there is
  nowhere to navigate.
- Hero column, centered: h1 → sub → [Download for Mac + Build from source ↗]
  → mono fact line. All vertical gaps are vh-clamped so 1280×720 compresses
  instead of clipping.
- The window: library.png (real capture) at min(1060px, 92vw), 12px radius,
  1px `--line-strong` edge, 0 24px 80px rgba(0,0,0,.55) shadow, top-aligned
  in the remaining flex space and CROPPED BY THE FOLD — the desktop motif is
  a window still on the desk. The crop is a bottom mask fade
  (`mask-image: linear-gradient`, black to 78% then transparent) so it
  dissolves into the ground instead of slicing text mid-line. On phones the
  full window fits, so it centers in the remaining ground with no mask.
- Escape hatch: `@media (max-height: 600px)` restores normal scrolling
  rather than clipping text on very short windows.

## Motion (entrance only)

- Children rise 14px + fade, 80ms stagger, 700ms expo-out
  (`cubic-bezier(.19,1,.22,1)`); the window settles from
  translateY(18px) scale(.985). Runs once on load, JS-gated (`html.js`),
  fully visible without JS and under `prefers-reduced-motion`.
- Hovers: CTA lifts 1px and brightens its glow; text links brighten.
  Nothing else moves. No scroll reveals; there is no scroll.

## Copy

Unslop voice, plain and factual, sentence case, no em dashes, no invented
claims. The whole page is five strings:

- h1: "Manage your AI skills."
- sub (value prop first, per user 2026-07-24 — do not lead with "free Mac
  menu-bar app"): "Skills and system prompts for all your agents, one click
  away. See what's active in Claude Code, Cursor, and OpenCode, switch
  anything off, edit your prompts."
- Buttons: "Download for Mac" (signed DMG release URL) · "Build from source"
- Facts: "Free, MIT · Signed and notarized · macOS 14+"

## Assets

- One image: `assets/library.png` (real capture, retaken 2026-07-24 from
  the current build with the architect skill focused; shows the SYSTEM
  PROMPTS sidebar, the skills list with green state dots, and the
  On/Name/Manual/Off segmented control — every capability the sub names is
  visible in the shot). A focused row shows its checkbox ticked and
  "1 of 43"; that is the app's designed Finder-style state, not noise.
  appicon.png as favicon + brand mark. Fonts self-hosted; zero third-party
  requests.
- Unused-by-the-page captures (menubar.png, popover.png, bulk.png) stay in
  `assets/` for OG cards or future use.

## App brand carryover

- Icon: graphite tile, corner-bracket slot grid, one slot equipped in green
  (`design/brand/loadout-icon.svg` → `Sources/Loadout/Resources/AppIcon.png`).
- Menu bar glyph: SF Symbol `backpack`.
- Terracotta stays inside the app; the page chrome is neutral + off-white.
