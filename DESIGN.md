---
name: Loadout
description: A quiet Mac-native instrument for skill management — warm graphite chassis, one identity green, played straight at the Things/Fantastical craft bar.
colors:
  ink: "#F2F0EC"
  ink-secondary: "#A8A49C"
  ink-tertiary: "#8A857C"
  chassis: "#151412"
  canvas: "#1C1B19"
  raised: "#252320"
  elevated: "#2B2926"
  hover: "rgba(255,255,255,0.05)"
  selection: "rgba(143,224,172,0.10)"
  separator: "rgba(255,255,255,0.07)"
  shadow: "rgba(0,0,0,0.42)"
  live: "#57B87A"
  live-vivid: "#6ECB8F"
  on-live: "#0D2114"
  partial: "#E0A340"
  danger: "#E97F71"
typography:
  display:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "26px"
    fontWeight: 600
  heading:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "17px"
    fontWeight: 600
  body:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "13.5px"
    fontWeight: 400
  body-medium:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "13.5px"
    fontWeight: 500
  row-detail:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "12px"
    fontWeight: 400
  meta:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "11.5px"
    fontWeight: 400
  meta-medium:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "11.5px"
    fontWeight: 500
  section-label:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "11px"
    fontWeight: 600
    letterSpacing: "0.5px"
  control:
    fontFamily: "SF Pro (system), -apple-system"
    fontSize: "12px"
    fontWeight: 500
  mono:
    fontFamily: "SF Mono (system, monospaced)"
    fontSize: "11.5px"
    fontWeight: 400
  editor:
    fontFamily: "SF Mono (system, monospaced)"
    fontSize: "13px"
    fontWeight: 400
rounded:
  sm: "7px"
  md: "10px"
  lg: "14px"
  full: "9999px"
spacing:
  unit: "4px"
  paneInset: "32px"
  titleBar: "40px"
  rowHeight: "56px"
  sidebarWidth: "240px"
  listWidth: "400px"
  readingWidth: "680px"
  editorWidth: "860px"
components:
  button-affirm:
    backgroundColor: "{colors.live}"
    textColor: "{colors.on-live}"
    rounded: "8px"
    height: "38px"
  button-affirm-hover:
    backgroundColor: "{colors.live-vivid}"
    textColor: "{colors.on-live}"
  button-neutral:
    backgroundColor: "{colors.raised}"
    textColor: "{colors.ink}"
    rounded: "8px"
    height: "38px"
  button-destructive:
    backgroundColor: "rgba(233,127,113,0.13)"
    textColor: "{colors.danger}"
    rounded: "8px"
    height: "38px"
  button-quiet:
    backgroundColor: "transparent"
    textColor: "{colors.ink-secondary}"
    typography: "{typography.meta-medium}"
    rounded: "6px"
  card:
    backgroundColor: "{colors.elevated}"
    rounded: "{rounded.md}"
    padding: "16px"
  chip:
    backgroundColor: "rgba(168,164,156,0.13)"
    textColor: "{colors.ink-secondary}"
    rounded: "{rounded.full}"
    padding: "3px 8px"
  toggle:
    backgroundColor: "{colors.live}"
    rounded: "{rounded.full}"
  checkbox:
    backgroundColor: "{colors.live}"
    rounded: "4px"
    width: "15px"
    height: "15px"
  search-field:
    backgroundColor: "{colors.raised}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
    height: "30px"
---

# Design System: Loadout

## Overview

**Creative North Star: "The Instrument, Not the Dashboard"**

Loadout is a warm-graphite Mac instrument in the Things/Fantastical school: real vibrancy, generous whitespace, system SF at true optical sizes, tactile controls, motion that is felt more than seen. It explicitly refuses the near-black-plus-hairline-grid look every AI utility ships — panes are told apart by tone and material, almost never by a drawn line. Dark is the primary, designed-in appearance (a quiet window that sits next to a terminal all day); light ships and is correct but is not where decisions get made.

Color carries meaning, not decoration. Green (`live`) is the app's one identity hue and is rationed to state: rails, switches, selection tint, the focus ring, the active tally dot. Amber (`partial`) means "not settled yet" and appears in exactly four places. Every colored state also carries its own word, so the app's state reads correctly in a grayscale screenshot.

The four surfaces — Library window, System Prompt editor, menu-bar popover, Settings window — share one token set and one set of primitives (`Card`, `ActionButton`, `StateControl`, `LoadoutToggle`, `SelectionCheckbox`). The Library and Prompt Editor windows hide their title bar and reserve a 40pt band for traffic-light air; the Settings window and menu popover are secondary surfaces and use the system title bar / floating chrome instead.

**Key Characteristics:**
- Warm graphite dark, four flat tones apart by luminance and material, not by rule
- One rationed identity green; every colored state also has a word
- System SF at real sizes, tabular digits on every count and date
- A single authored spring (the four-state control); everything else is a 130ms fade
- Reading columns capped (680/860pt) so wide windows never produce a wall of text

## Colors

Four warm-graphite surface tones plus a small, strictly-rationed state palette. All colors are defined as light/dark pairs (`Color(light:dark:)`); dark is normative since dark is the primary appearance — light values are noted alongside for completeness.

### Primary
- **Live Green** (`#57B87A` dark / `#26794A` light): the app's identity hue. Used only for: the state rail when a skill is live, the toggle tint, selection tint, the search field's focus ring, the active-count dot, and the affirmative action button (`onLive` on top of it: `#0D2114` dark / `#FFFFFF` light, chosen per-mode so contrast never drops below ~5:1).
- **Live Vivid** (`#6ECB8F` dark / `#2E9159` light): brighter green for fills that need to read against the hue itself — the affirmative button's hover state.

### Secondary
- **Partial Amber** (`#E0A340` dark / `#9A6511` light): "in between," not live and not off. Exactly four uses in the built app: the name-only/manual-only override chip, the "Manual-only" frontmatter fact chip, the unsaved-edit save-status dot in the prompt editor, and the disk-conflict banner. No other use is sanctioned.
- **Danger** (`#E97F71` dark / `#A33228` light): destructive actions and error text only — delete confirmation, quiet-button destructive role, the conflict/error save status.

### Neutral
- **Ink** (`#F2F0EC` dark / `#1E1C19` light): primary text.
- **Ink Secondary** (`#A8A49C` dark / `#635F58` light): secondary text, descriptions, unselected sidebar labels.
- **Ink Tertiary** (`#8A857C` dark / `#797469` light): meta, captions, placeholder icons. Verified ≥4.5:1 on `canvas` in both appearances.
- **Chassis** (`#151412` dark / `#EAE8E3` light): the deepest tone, behind the sidebar's vibrancy material.
- **Canvas** (`#1C1B19` dark / `#FBFAF8` light): list and detail ground.
- **Raised** (`#252320` dark / `#F1EFEA` light): wells sunk into the canvas — search field, prompt editor well, code blocks.
- **Elevated** (`#2B2926` dark / `#FFFFFF` light): floating surfaces — cards, the menu-bar popover.
- **Hover** (5%/4.5% white/black wash), **Selection** (10% wash of `live`, not gray — the app's own hue), **Separator** (7–8% white/black, hairline only).

### Named Rules
**The One Green Rule.** `live` is the identity hue and appears only at: rails, switches, selection tint, the focus ring, and the active tally dot (plus the affirmative button, its one filled-surface use). It is never used for decoration or emphasis outside a state signal.

**The Four Ambers Rule.** `partial` has exactly four sanctioned uses (documented in `Theme.swift`): the name-only/manual-only state, the "Manual-only" frontmatter chip, unsaved prompt-editor edits, and the disk-conflict notice. Do not reach for amber as a generic "warning" color outside those four.

**The Grayscale Survival Rule.** No state is encoded in color alone. The state rail also changes position/height; the row also prints the state's word (Name / Manual / not in Claude) when it isn't plainly "on" or "off"; the checkbox shows a checkmark or minus glyph, not just a fill.

## Typography

**Display/Body/Label Font:** SF Pro (system, San Francisco) at real optical sizes — no custom typeface.
**Mono Font:** SF Mono (system, monospaced) — the prompt editor body and inline paths/code.

**Character:** One system family used expertly across a tight, mostly-13px-and-under ramp. Weight and color carry hierarchy far more than size does; only `display` (26pt) and `heading` (17pt) break out of the 11–14pt band the rest of the app lives in.

### Hierarchy
- **Display** (semibold, 26px): pane titles only — skill name in the detail header, system-prompt filename in the editor header. Exactly one per pane.
- **Heading** (semibold, 17px): "Nothing selected," Settings identity, popover title.
- **Body** (regular, 13.5px): descriptions, editor-adjacent prose, empty-state messages.
- **Row Title** (medium, 13.5px): skill row names.
- **Row Detail** (regular, 12px): skill row description/subtitle line.
- **Meta / Meta Medium** (regular/medium, 11.5px): dates, counts, captions, metadata pairs.
- **Section Label** (semibold, 11px, uppercase, 0.5px tracking): "System Prompts," "Skills," "In Claude Code," "Other Tools." Weight carries the label, not tracking gymnastics.
- **Control** (medium, 12px): the four-state control's segment labels.
- **Editor** (regular, 13px, monospaced): the system-prompt `TextEditor` body.

### Named Rules
**The Real Optical Size Rule.** Type is set at the sizes SF actually reads best at on the Mac (13.5 for body, not a web-derived 14 or 16); nothing is scaled up to fill space.
**The One Display Per Pane Rule.** `display` (26pt) never appears twice in the same pane — it marks the single thing the pane is about.
**The Tabular Digits Rule.** Every count and date (`activeCount`, char counts, relative dates) is `.monospacedDigit()` with `.contentTransition(.numericText())`, so numbers roll instead of jump and never reflow their neighbors.

## Layout

Four surfaces share tokens, not a shared frame: Library and Prompt Editor are panes inside one hidden-title-bar window (`minWidth: 940, minHeight: 580`); Settings is a fixed 400pt system-chrome window; the menu-bar popover is a fixed 312pt floating panel.

The Library window is a plain `HStack`, not `NavigationSplitView`: a 240pt vibrancy sidebar, then either a 400pt skill list + flexible detail pane, or (when a system prompt is selected) a full-width editor pane. Every pane reserves `Theme.titleBar` (40pt) at its top for traffic-light air — the window itself hides its title bar, so this is the only thing standing in for it.

Prose and code never run the full width of a wide window. The skill-detail document is capped at `readingWidth` (680pt); the prompt editor's column is capped at `editorWidth` (860pt, wider because mono runs narrower per character) — both centered in the available pane rather than left-pinned.

Spacing is a 4pt rhythm (`Theme.unit`) throughout — row height 56pt, pane inset 32pt, control heights (24/28/30/38pt) all fall on 2pt-aligned stops derived from it.

### Named Rules
**The One Seam Rule.** Exactly one hairline separator exists in the whole app: the list↔detail boundary in the Library window, because those two panes share a tone and genuinely need a seam to read as two panes. Every other boundary (sidebar↔list, header↔body, popover row↔row) separates by tone, material, or air — not a rule.
**The Sibling Controls Rule.** Interactive row controls (checkbox, switch, select button) are laid out as siblings, never nested inside one another's tap target, so a checkbox click can never also dispatch row selection.

## Elevation & Depth

Hybrid: mostly tonal layering (four flat surface tones — chassis/canvas/raised/elevated), with one real, offset drop shadow reserved for things that actually float (`Card`, used for the state card and Settings' two cards). The sidebar is the one surface with true behind-window vibrancy (`NSVisualEffectView`, `.sidebar` material) rather than a flat fill — "one true vibrancy sidebar," per the direction contract.

### Shadow Vocabulary
- **Card shadow** (`color: shadow (13% light / 42% dark black), radius: 8, y: 2`): the only shadow in the system. Used for anything on the `elevated` tone that is meant to read as genuinely floating above `canvas`.

### Named Rules
**The Flat-Unless-Floating Rule.** Nothing gets a shadow just because it's a container. Only surfaces meant to read as physically above the canvas (cards, not panes) take the Card shadow.

## Shapes

Three radius steps, all softly rounded, no sharp corners anywhere in the system: `radiusSmall` (7px — search field, buttons, state-control track), `radius` (10px — cards, rows, the state control's inner segments run 7px), `radiusLarge` (14px — reserved for the largest surfaces). The checkbox is its own small step (4px) to read as a distinct control rather than a miniature card. Full capsules (`Capsule()`, effectively 9999px) are used for the state rail, chips, and switches — the one place the system goes fully round.

## Components

### Buttons
- **Shape:** 8–9px corner radius (`radiusSmall + 1`), matching the system's small-radius step.
- **ActionButton — Affirm:** filled `live` (hover: `liveVivid`), `onLive` text, 38pt tall, full-width in the bulk pane. One affirmative fill per screen — "a screen with three equal buttons has no primary."
- **ActionButton — Neutral:** `raised` fill (hover: `elevated`), `ink` text.
- **ActionButton — Destructive:** `danger` at 13% opacity (hover: 22%), `danger` text.
- **QuietButtonStyle:** no chrome at rest; on hover, `Theme.hover` background and text steps from `inkSecondary` to `ink` (or to `danger` for the destructive role). Used for secondary actions (Save, Reload File, Open Logs, Check for Updates) — text-first, chrome only on demand.
- **GhostIconButton:** 28×28pt icon-only, no chrome idle, `Theme.hover` (or danger wash) on hover. Header actions (reveal in Finder, delete, settings gear).

### Cards / Containers
- **Corner Style:** 10px (`Theme.radius`).
- **Background:** `elevated` tone.
- **Shadow Strategy:** see Elevation & Depth — the Card shadow, always.
- **Border:** none.
- **Internal Padding:** 14–16pt.

### Inputs / Fields
- **Search field:** a well sunk into `canvas` (background `raised`, 7px radius, no border at rest) — "a well, not a raised chip on top of it."
- **Focus:** a 1.5pt `live` stroke at 55% opacity appears on focus; nothing else moves.
- **Prompt editor:** same well treatment at 10px radius, monospaced body, no border; a disk-conflict state adds an amber banner above it rather than recoloring the well itself.

### Toggles & Selection
- **LoadoutToggle:** the system `.switch` style, `controlSize(.small)`, tinted `live` — the plain on/off used everywhere state is binary (skill active, other-tool shelving, launch at login).
- **SelectionCheckbox:** 15pt square (30×40pt hit target), `live` fill with a white/near-black checkmark when on, a hollow `inkTertiary`-stroked square at rest, a minus glyph for mixed/indeterminate. Fades in on row hover so multi-select is discoverable without knowing ⌘-click; stays visible once selected.

### Chips
- **Style:** small capsule, 13% tint of the chip's own color as background, same color as text (e.g. `live` for "Managed," `partial` for "Manual-only," `danger` for "Broken link," neutral `inkSecondary` for "Symlinked" / "Not installed").
- **State:** informational only — chips are never interactive.

### The Four-State Control (signature component)
`StateControl` is the one authored motion moment in the app: On / Name / Manual / Off as a single segmented control whose capsule background springs (`Theme.spring`, response 0.34, damping 0.78) between positions and lands tinted in that state's color (22% wash of `live` or `partial`, or a neutral 16% wash for Off) — the label itself always stays ink-colored, so legibility never depends on the fill. Everything else in the app animates with `Theme.fade` (130ms ease-out, hover/reveal) or `Theme.snap` (260ms spring, state commits, counts); this is the only spring the user is meant to notice.

### State Rail
A 3pt capsule on a row's leading edge: full-height and full-opacity when live, short (18pt) and 85%-opacity when partial, absent (0-height, clear) when off or unavailable. Position, height, and color all encode state redundantly, by design (see the Grayscale Survival Rule).

### Empty States
Centered icon (28px, light weight, `inkTertiary`) + `heading`-weight title + optional `body`/`inkTertiary` message capped at 320pt wide. Used identically across the skill list, skill detail, and prompt editor — never a bespoke illustration.

## Do's and Don'ts

### Do:
- **Do** ration `live` green to state signals only: rails, switches, selection, focus ring, active-count dot, and the one affirmative button fill.
- **Do** tell panes apart with tone, material, and air first; reach for a hairline separator only where two panes share a tone and genuinely need a seam (today: exactly one place, list↔detail).
- **Do** cap prose and code columns (680pt reading, 860pt editor) even in a maximized window.
- **Do** give every colored state its own word, not just its color, so state survives a grayscale screenshot.
- **Do** lay row-level interactive controls out as siblings, never nested inside a larger tap target.
- **Do** use real vibrancy (`NSVisualEffectView`) for the sidebar, not a translucent color pretending to be material.

### Don't:
- **Don't** use `partial` amber as a generic "warning" or "attention" color — its four uses are enumerated and closed.
- **Don't** add a shadow to a container just because it's a container; shadows are reserved for things that are actually meant to float above the canvas (Cards).
- **Don't** introduce a second spring-based motion moment; `Theme.spring` is reserved for the four-state control specifically so it stays a signature rather than a house style.
- **Don't** draw a border/hairline as a default separator between sibling elements — it is the documented exception, not the grammar, in a system whose thesis explicitly refuses the "near-black-plus-hairline-grid" look common to AI utilities.
