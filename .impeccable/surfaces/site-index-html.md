---
version: 1
slug: "site-index-html"
primary_target: "site/index.html"
related_targets: []
---

# Surface brief: site/index.html (Loadout landing page)

Mode: Persuade. Scope: single static page, source of truth `site/`, deployed
via personal-website repo at ovsh.github.io/loadout/ (run `scripts/sync-site.sh`
after edits, commit both repos).

Audience & job: developers running AI coding tools (Claude Code, Cursor,
OpenCode, agents dir) on a Mac with dozens of skills accumulated on disk.
They arrive from GitHub or a link, deciding in seconds whether this menu-bar
app is worth installing.

Outcome: click Download (signed DMG v0.5.0,
https://github.com/ovsh/skillbox/releases/download/v0.5.0/Loadout-MacOS.dmg)
or build from source.

Confirmed content spine (user-approved 2026-07-23, unchanged):
1. What it is: every skill your AI tools have, one switch each.
2. See it: REAL screenshots only (library window hero, menu bar + popover).
3. How it works: three mechanisms as evidence rows: sanctioned
   `skillOverrides` writes (live, folder never moves, values on / name-only /
   user-invocable-only / off) · lossless per-tool shelving · global prompt
   editor (CLAUDE.md / AGENTS.md).
4. Trust: backs up settings.json once, owns exactly one key, delete goes to
   Trash, MIT open source, networking disclosure (GitHub update check +
   PostHog analytics, random install id, skill names never contents).
5. Action: Download + build from source.

Chosen direction (standing user preference, 2026-07-24, PRODUCT.md Brand
Commitments): the conventional modern Mac-app landing page played straight at
Raycast's craft bar; "Instrument" world recorded in DESIGN.md. Themed worlds
(patch-notes, pixel-art) are permanently excluded for this surface.
Memorable moment: the skillOverrides toggle demo that edits real JSON.

Proof on hand: the real app (buildable, screenshottable), mechanism truth in
PLAN.md/README.md, MIT license. No testimonials, user counts, or benchmarks
exist; never invent. Unslop voice everywhere including <title>.

Unresolved: none.
