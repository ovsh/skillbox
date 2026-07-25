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
- The window: an auto-playing SIMULATION of the app (2026-07-25, replacing
  the static fold-cropped library.png). The `.stage` keeps the window's
  2120:1300 aspect, fits the remaining flex space (16:10-clamped width),
  12px radius, 1px `--line-strong` edge, 0 24px 80px rgba(0,0,0,.55) shadow.
  Inside, a `.film` layer (two full-frame captures crossfading: library /
  AGENTS.md editor, plus pixel-aligned overlay patches) is panned and zoomed
  per beat: `transform-origin: 0 0`, translate+scale with edge clamping.
  Below the stage: caption line + scrubber (range input) + play/pause.
- Escape hatch: `@media (max-height: 620px), (max-width: 420px)` restores
  normal scrolling rather than clipping text on very short windows; `main`
  gets `justify-content: safe center` there.

## Motion

- The simulation: 9 beats, ~17s loop, driven by a rAF clock with a
  fractional beat timeline. Every product pixel is a real screenshot crop
  (`assets/sim/`); the only synthetic pixels are the hollow pointer ring
  and the click ring. Beats: library → open prompts → type a line into
  AGENTS.md → autosave chip → back to library → Name-only toggle → Off
  toggle → dimmed row + count drop → back On. IntersectionObserver gates
  playback; the scrubber seeks; `prefers-reduced-motion` and no-JS both
  render the static first frame with all copy visible.
- Entrance: children rise 14px + fade, 80ms stagger, 700ms expo-out
  (`cubic-bezier(.19,1,.22,1)`); the stage settles from
  translateY(18px) scale(.985) (released via `.sim.rv:not(.in)` — the
  `:not` keeps the settled state from being outranked). Runs once on load,
  JS-gated (`html.js`), fully visible without JS.
- Hovers: CTA lifts 1px and brightens its glow; text links brighten.

## Copy

Unslop voice, plain and factual, sentence case, no em dashes, no invented
claims. Benefit-first per user 2026-07-25 ("we're not telling users whats
the benefit"):

- h1: "Skills are hard to find and harder to switch off."
- sub: "They sit in folders you have to remember, and every new model wants
  a different setup. Loadout puts them all in one window with a switch on
  each, and keeps CLAUDE.md and AGENTS.md a click away. That's all it does."
- Buttons: "Download for Mac" (latest-release DMG URL) · "Build from source"
- Facts: "Free, MIT · Signed and notarized · macOS 14+"
- Plus one caption per simulation beat, present tense, one clause each.

## Assets

- `assets/sim/` — the simulation's captures, all from the real app
  (2026-07-25 build): `sim-lib.webp` + `sim-prompt.webp` (full 2120×1300
  frames), `ov-edit.webp`, `ov-name.webp`, `ov-off.webp`, `ov-off-row.webp`,
  `ov-off-count.webp`, `ov-edit-chars.webp` (pixel-aligned overlay patches).
  The AGENTS.md editor capture shows a generic section, NOT the user's
  private CLAUDE.md (their model-cost table must never be published).
- `assets/og.jpg` — social card. appicon.png as favicon + brand mark.
  Fonts self-hosted; zero third-party requests.
- The old static captures (library.png, menubar.png, popover.png, bulk.png)
  were removed 2026-07-25; the simulation replaced them.

## App brand carryover

- Icon: graphite tile, corner-bracket slot grid, one slot equipped in green
  (`design/brand/loadout-icon.svg` → `Sources/Loadout/Resources/AppIcon.png`).
- Menu bar glyph: SF Symbol `backpack`.
- Terracotta stays inside the app; the page chrome is neutral + off-white.
