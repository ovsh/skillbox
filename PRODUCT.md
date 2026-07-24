# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

> The product itself is a native macOS menu-bar app (SwiftUI, macOS 14+). The
> surface this file primarily serves is its **landing page** (web). Native app
> design work follows the incumbent in-app system recorded in
> `design/DIRECTION-A.md` ("Graphite").

## Users

Developers who use AI coding tools (Claude Code, Cursor, the agents standard,
OpenCode) on a Mac and have accumulated dozens of skills across
`~/.claude/skills`, `~/.agents/skills`, `~/.cursor/skills`, and
`~/.config/opencode/skills`. Their job: know what skills their tools actually
have, turn them on or off per tool without hand-editing JSON or moving
folders, and see/edit what their global agent prompt actually says.
Single-player: no team, no GitHub account required to get value.

## Product Purpose

Loadout (formerly Skillbox) is an always-on menu-bar macOS app: the personal
skill manager for AI coding tools. Open it and instantly see every installed
skill with real metadata (active or not, when added, when last touched, which
tools see it), flip each one on or off, and edit global agent prompts
(`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`) inline. Success = the user
trusts it as the single quiet control panel for their agent gear.

The name comes from gaming: a loadout is the gear you take into a match. The
app is where you equip your agents before the work starts.

## Positioning

The only manager that uses the mechanism each tool actually sanctions instead
of one blunt hack: for Claude Code and the Agent SDK it writes the documented
`skillOverrides` map in `~/.claude/settings.json` (file-watched — toggles
apply to live sessions; the skill folder never moves). For tools with no
override map (Cursor, agents dir, OpenCode) it shelves the folder losslessly
and restores it byte-identical. Symlinked skills are never moved.

## Operating Context

Menu bar first: a quiet, always-on presence next to the clock. The library
window opens for deliberate management sessions; the popover answers "what's
active" in two seconds. Directory watchers keep everything current when tools
or a `git pull` change the skills folders. Sits alongside terminal AI tools
all day.

## Capabilities and Constraints

- Library across all four skills directories; unified inventory incl. symlinks.
- Per-skill 4-state control for Claude Code: on / name-only /
  user-invocable-only / off (= `skillOverrides` values).
- Per-tool shelving for Cursor / agents dir / OpenCode; lossless restore.
- Prompt editor with autosave that never clobbers concurrent on-disk edits.
- Bulk actions, multi-select, search, delete-to-Trash (never `rm`).
- Swift 6 SwiftPM app, macOS 14+, engine (`SkillboxKit`) fully unit-tested.
- Registry/team sync exists in the Kit with zero UI (future team mode).
- Self-updates from GitHub Releases (repo: github.com/ovsh/skillbox — repo
  name deliberately NOT renamed; only the product name changed to Loadout).

## Brand Commitments

- Name: **Loadout** (renamed from Skillbox, 2026-07-23; user-confirmed scope:
  app bundle `Loadout.app` + bundle id `com.ovsh.loadout`; GitHub repo slug and
  local dir stay `skillbox`).
- In-app design system: "Graphite" (design/DIRECTION-A.md) — near-black
  instrument neutrals, color only where state lives (dim green = active,
  terracotta accent). The landing page's world is separate and derives from
  the gaming loadout concept; it must NOT reuse the sibling PowerWatch site's
  pixel-sky "Daylight" look.
- User asked for a new app icon and brand style informed by current design
  inspiration found online (mood-board ingestion per design-motion skill).
- STANDING LANDING-PAGE PREFERENCE (user, 2026-07-24): the conventional
  modern Mac-app landing page, played straight, at Raycast's craft bar. The
  themed "Balance Patch" world was built, shipped, and rejected by the user
  ("doesn't feel like a normal landing page"). Do not pitch themed worlds
  for the landing page again; execute the category standard at full
  fidelity. PowerWatch's pixel-sky look also remains excluded.
- Voice: plain, factual, quiet confidence. Safety posture stated concretely
  (backs up settings.json once, patches only the one key it owns, everything
  reversible), never marketed as vague "safe & secure".

## Evidence on Hand

- The real app, buildable from this repo (`swift build`), screenshottable.
- Mechanism truth researched and documented in PLAN.md (skillOverrides is
  Claude Code's sanctioned per-skill toggle; file-watched).
- MIT license; open source.
- No testimonials, user counts, or benchmarks exist — never invent them.
- Signing: Developer ID "Digital Lane LLC" (7Z82LSPAPP). v0.5.0 app and DMG
  signed, notarized (Accepted), and stapled on 2026-07-24 via the
  `digital-lane` notarytool profile; verified with spctl and stapler.

## Product Principles

1. Sanctioned mechanisms over clever hacks — do what each tool documents.
2. Reversible always: deactivation hides, nothing is ever destroyed.
3. Quiet instrument, not a dashboard — the app earns its always-on spot by
   staying out of the way.
4. Real metadata, real state — show ground truth from disk, never a cache lie.
5. Single-player first — value with zero accounts, zero setup.
