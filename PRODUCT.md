# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos

> Impeccable's schema enumerates `web` / `ios` / `android` / `adaptive`. This
> product is none of them: a native **macOS** menu-bar app (SwiftUI, Swift 6,
> macOS 14+). Design work follows macOS AppKit/SwiftUI idioms and the Apple
> HIG for the Mac — not iOS patterns, not web patterns.
>
> One web surface exists and is secondary: the landing page in `site/`. Its
> brief is `.impeccable/surfaces/site-index-html.md` and its world is
> `design/LANDING.md`. Nothing about that page governs the app.

## Users

Developers who use AI coding tools — Claude Code, the Agent SDK, Cursor, the
agents standard, OpenCode — on a Mac, and who have accumulated dozens of
skills scattered across `~/.claude/skills`, `~/.agents/skills`,
`~/.cursor/skills`, and `~/.config/opencode/skills`.

Their job, mid-workday, terminal open: know which skills their agents
actually have loaded, turn a skill on or off for a specific tool without
hand-editing JSON or dragging folders around, and read or edit what their
global agent prompt actually says. Single-player: no team, no account, no
GitHub required to get value.

## Product Purpose

Loadout is an always-on macOS menu-bar app: the personal skill manager for AI
coding tools. Open it and see every installed skill with real on-disk
metadata — active or not, when it was added, when it last changed, which
tools can see it — flip each one on or off, and edit global agent prompts
(`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`) inline.

Success is trust: the user treats it as the single quiet control panel for
their agent gear and stops opening a text editor to check settings.json.

The name comes from gaming — a loadout is the gear you take into a match.
The app is where you equip your agents before the work starts.

## Positioning

The only manager that uses the mechanism each tool actually sanctions instead
of one blunt hack.

- Claude Code and the Agent SDK: writes the documented `skillOverrides` map in
  `~/.claude/settings.json`. Claude Code file-watches that file, so a toggle
  applies to live sessions, and the skill folder never moves.
- Tools with no override map (Cursor, agents dir, OpenCode): shelves the
  folder losslessly and restores it byte-identical.
- Symlinked skills are never moved — only the link is ever touched.

## Operating Context

Menu bar first: a quiet, always-on presence next to the clock, answering
"what's active" in two seconds via the popover. The library window opens for
deliberate management sessions — auditing what accumulated, bulk-disabling a
plugin's worth of skills, rewriting a system prompt. Directory watchers keep
everything current when a tool, an install, or a `git pull` changes the skills
folders underneath. It sits alongside terminal AI tools all day and must never
demand attention.

## Capabilities and Constraints

- Unified library across all four skills directories, including symlink
  resolution and per-tool presence.
- Per-skill 4-state control for Claude Code: On / Name-only /
  User-invocable-only / Off (the `skillOverrides` values).
- Per-tool shelving for Cursor / agents dir / OpenCode, with lossless restore.
- System prompt editor with autosave guarded against clobbering concurrent
  on-disk edits; conflict banner when the file changed underneath.
- Search, multi-select with checkboxes, bulk enable/disable, delete-to-Trash
  (`FileManager.trashItem`, never `rm`).
- Menu-bar popover (active count, recent skills, Open / Quit) and a Settings
  window (launch at login, update checks).
- Swift 6 SwiftPM, macOS 14+. Engine (`LoadoutKit`) is UI-free and unit
  tested; `swift build && swift test` green is the shipping gate.
- Rendering constraint: markdown rendering (MarkdownUI) and the disk scan must
  never block the UI. Prior versions shipped visible click lag; that is a
  regression class, not a nice-to-have.
- Registry / team sync exists in the Kit with zero UI. Future team mode.
- Self-updates from GitHub Releases. Repo slug and local directory stay
  `skillbox`; only the product name changed.
- Analytics via PostHog.

## Brand Commitments

- **Name: Loadout** (renamed from Skillbox, confirmed 2026-07-24). Scope of
  the rename: user-facing product name, app bundle `Loadout.app`, bundle id
  `com.ovsh.loadout`, and the Swift targets `Loadout` / `LoadoutKit`. The
  GitHub repo slug and the local directory stay `skillbox` — deliberately, so
  existing release URLs and the v0.5.0 self-updater keep working.
- **The incumbent in-app visual system, "Graphite"** (`design/DIRECTION-A.md`:
  near-black instrument neutrals, hairlines, dim green = active, rationed
  terracotta accent), **was replaced** in the 2026-07-25 redesign, with the
  user's explicit permission. DIRECTION-A.md and `design/directions.html`
  are now anti-reference, not current truth; the app's design system is
  DESIGN.md at the repo root.
- **STANDING IN-APP PREFERENCE (user, 2026-07-24): the category standard,
  played straight, at the Mac-native craft bar.** Offered a rolled visual
  world ("Overhead Panel", an aircraft annunciator system) and a fused
  alternate ("One-Bit Desktop"), the user took the canon exit. Do not pitch
  themed or metaphor-driven worlds for the app again. The named peers whose
  craft level is the bar: **Things and Fantastical** — the Mac-native school:
  real materials and vibrancy, generous whitespace, system typography used
  expertly, tactile controls with honest depth, Apple-grade motion. Execute
  that canon at full fidelity, without irony and without smuggled quirk.
- **Dark is the primary mode** (user, same session). Light mode ships and must
  be correct, but design decisions are made in dark — that is the scene: a
  quiet window next to a terminal all day.
- The user asked for a new app icon and a brand style informed by current
  design inspiration.
- Voice: plain, factual, quiet confidence. Safety posture is stated
  concretely — backs up `settings.json` once, patches only the one key it
  owns, everything reversible — never marketed as vague "safe & secure".
- **STANDING LANDING-PAGE PREFERENCES (user, 2026-07-24), for `site/` only.**
  Two rulings, both from surfaces that were built and rejected: (1) the
  conventional modern Mac-app landing page, played straight, at Raycast's
  craft bar — the themed "Balance Patch" world was rejected ("doesn't feel
  like a normal landing page"), and PowerWatch's pixel-sky look stays
  excluded; do not pitch themed worlds for the page again. (2) A single
  viewport, no scrolling — the long multi-section build was rejected ("too
  convoluted"). Statement, one supporting line, one Download CTA, one real
  screenshot; mechanism detail lives in the README.

## Evidence on Hand

- The real app, buildable and runnable from this repo (`swift build`,
  `./scripts/package_app.sh`), and therefore screenshottable for verification.
- Mechanism truth researched and written up in `PLAN.md`: `skillOverrides` is
  Claude Code's sanctioned per-skill toggle and is file-watched.
- `design/DIRECTION-A.md` + `design/directions.html`: the shipped Graphite
  direction, as an anti-reference for the replacement world.
- MIT licensed, open source.
- Signing identity: Developer ID "Digital Lane LLC" (7Z82LSPAPP); notarization
  via the `digital-lane` notarytool profile, which is already stored in the
  login keychain and is team-wide (shared with the user's other apps — one
  profile covers every app under 7Z82LSPAPP). v0.5.0 shipped signed,
  notarized (Accepted), and stapled on 2026-07-24.
- GitHub Actions holds **zero** repository secrets, so the CI release workflow
  cannot sign or notarize — every signing step there is gated on a secret
  being present and silently skips. Releases are signed locally.
- No testimonials, user counts, benchmarks, or revenue exist. Never invent
  them.

## Product Principles

1. Sanctioned mechanisms over clever hacks — do what each tool documents.
2. Reversible always: deactivation hides, nothing is ever destroyed.
3. A quiet instrument, not a dashboard. It earns its always-on spot by
   staying out of the way.
4. Real state, read from disk. Never show a cached lie about what's active.
5. Single-player first — full value with zero accounts and zero setup.

## Accessibility & Inclusion

No product-specific requirement was established beyond platform norms: honor
macOS Light/Dark and Increase Contrast, keep hit targets reachable, keep text
legible at system sizes, and never encode state in color alone (the on/off
distinction must survive a grayscale screenshot).
