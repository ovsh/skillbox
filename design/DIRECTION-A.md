> **SUPERSEDED — 2026-07-25.** The "Graphite" system described here was
> replaced by the redesign recorded in `DESIGN.md` at the repo root. This
> file is kept as history and anti-reference. Names below (`Skillbox`,
> `SkillboxKit`) predate the Loadout rename. Do not implement from it.

# Skillbox — Direction A "Graphite" Implementation Plan

The approved design direction (see `design/directions.html`, tab A, for the living
mockup). This doc is self-contained: someone with no other context can implement
from it. Repo: Swift 6 SwiftPM, macOS 14+, app target `Skillbox`, engine `SkillboxKit`.

## Thesis

An instrument that sits next to the OpenAI Codex desktop app: near-black neutrals,
monochrome line iconography, hairline borders, color appears **only where state
lives** (dim green = active, terracotta = the accent, rationed). No system-blue
selection anywhere. No badges. No bulky control cards.

## Tokens (Theme.swift replaces the warm-paper palette)

Dark (primary):
- canvas `#101012`, panel `#151518`, raised `#1B1B1F`, hover `#202024`
- ink `#E9EAEC`, mute `#9A9DA4`, faint `#5C5F66`
- hairline `white @ 7%`, selection `white @ 6%`
- live (active state) `#58A56E`, accent `#D4795A`

Light (secondary, same structure): canvas `#F7F7F8`, panel `#FFFFFF`, raised
`#F1F1F3`, ink `#1D1D20`, mute `#6B6E76`, faint `#A2A5AD`, hairline `black @ 8%`,
selection `black @ 5%`, live `#3E8B55`, accent `#C2593A`.

Type: system SF only. 13/12/11 UI; content title 21/650; captions 10.5; paths and
counts monospaced-digit. Small-caps section labels 10/700 with 0.08em tracking.

## Window layout (custom, not NavigationSplitView)

One HStack, full custom control (kills the blue List selection for good):

```
┌ sidebar 218 ┬ list 356 ┬ detail (fluid) ┐   ← Skills selection
├ sidebar 218 ┴ editor (fluid) ───────────┤   ← System-Prompt selection
```

Sidebar (top→bottom):
1. `SYSTEM PROMPTS` section — the discovered prompt files (CLAUDE.md, AGENTS.md,
   …) as items directly in the sidebar. Selecting one shows the editor across
   the full remaining width (no middle column).
2. `SKILLS` section — All Skills (count as quiet right-aligned text, not a
   badge), then one filter row per tool that has ≥1 skill.
3. Footer: live-dot + "N of M active" + gear (opens Settings).

## Library list

- Search field pinned on top: raised background, magnifier, `⌘K` hint chip;
  ⌘K focuses it.
- Rows 44pt: **status dot** (7pt, green when Claude-active, hollow when off,
  hidden when skill not in Claude) that **morphs into a small switch on row
  hover** (`opacity` crossfade, 120ms). Name 13/500, description 11.5 mute,
  relative time 10.5 faint tabular. Off rows dim text to 50%.
- Selection = 6% white wash, 8pt radius. Hover = `hover` token.

## Detail pane

Header row (single line, all baseline-aligned):
`title (21/650)` … `slim 4-state pill` `folder ghost` `trash ghost`

- **Slim pill** (the activation control, moved out of the old card):
  segments On / Name / Manual / Off, 10.5/600, 5×11pt padding, hairline
  border, selected segment = 13% white fill; selected **Off** = terracotta fill.
  Maps to `skillOverrides`: On = remove entry, Name = `name-only`,
  Manual = `user-invocable-only`, Off = `off`.
- One caption line under the header explains the current state, e.g.
  "On — Claude can invoke this skill, and /architect runs it directly.
  Off hides it from Claude; files stay on disk."
- Ghost icons: 26pt hairline squares. Folder = Reveal in Finder. Trash = delete
  (see below). Trash hover tints `#E5695A`.
- Then: description lede, meta line (Added · Updated · In tools · chips),
  hairline, rendered SKILL.md (frontmatter stripped; duplicate H1 == title
  dropped).
- Skills not present live in `~/.claude/skills`: pill disabled, caption
  explains Claude can't load it.

## Delete (new capability)

- Semantics: **deactivate hides, delete removes.** Deactivate = `skillOverrides`
  entry, folder untouched. Delete = for every presence of the skill:
  real folder → `FileManager.trashItem` (Trash, never rm); **symlink → remove
  the link only, never the target**; then clear the skill's `skillOverrides`
  entry and re-scan.
- UI: trash ghost in the detail header → `confirmationDialog`:
  title `Delete "name"?`, body adapts (folder → "moves the skill folder to the
  Trash"; symlink → "removes the link; the original files stay where they
  are"), destructive button `Move to Trash`.
- Engine: `SkillboxKit/SkillDeleter.swift` + tests (temp-dir fixtures; verify
  link-only removal for symlinks, override cleanup, missing-source tolerance).

## System Prompts (rename from "Prompts")

- All user-facing strings say **System Prompts**.
- Editor header: filename 17/650, mono path + which tools read it, right side:
  char count · save state ("Saved just now" / "Unsaved — autosaves shortly" in
  accent) · `⌘S` chip. Editor surface: raised token, hairline, 10pt radius,
  mono 12.5/1.7. Conflict banner behavior unchanged from v2.

## Menu bar popover + Settings

Recolor to Graphite tokens; popover keeps: header (icon, "N of M active"),
5 recent skills with dot+switch, Open Skillbox / Quit. Settings unchanged
structurally.

## Non-goals (unchanged from v2)

Registry/team sync stays dormant; no per-tool shelving changes; watchers,
optimistic toggles, conflict guards, and settings-write safety are already in
place and must not regress. `swift build && swift test` green is the gate.
