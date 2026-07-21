# Skillbox v2 Plan — Single-Player Skill Manager

Working doc for the v2 pivot. Adversarially reviewed by codex gpt-5.6 (xhigh), ≤3 turns.

## 1. Product

The app is **the user's personal skill manager**. Open it and instantly see every
skill installed for your AI tools, flip them on/off, and edit your global agent
prompts (CLAUDE.md / AGENTS.md) inline. No GitHub, no teams, no onboarding.
Team/registry sync stays in SkillboxKit but has **zero UI** in v2.

Primary surfaces:
1. **Library window** — sidebar (All Skills, per-tool filters, Prompts), skill
   list with switches + "added / last touched" metadata, detail pane with
   rendered SKILL.md, frontmatter chips, per-tool presence.
2. **Prompt editor** — global agent prompts, inline editable, ⌘S + debounced
   autosave, char count and last-modified. Candidate files discovered from a
   data-driven list (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`,
   `~/.config/opencode/AGENTS.md`, `~/AGENTS.md`); only existing files shown,
   plus "create" affordance for the canonical two.
3. **Menu bar popover** — "N skills active · M shelved", 5 most recently
   touched skills with inline switches, Open Library, Quit. Always-on, light.

## 2. Activation mechanics (research-confirmed)

Two mechanisms, used for what each is actually sanctioned for:

**Primary — Claude Code + Agent SDK: `skillOverrides`.** Claude Code's
documented per-skill toggle is the `skillOverrides` map in
`~/.claude/settings.json`: `"on" | "name-only" | "user-invocable-only" | "off"`.
It's file-watched (applies live, mid-session, no restart) and governs Agent SDK
callers too (SDK defaults to settingSources including "user"). The built-in
`/skills` TUI writes this same key. So:
- List switch = write `skillOverrides[dirName] = "off"` / remove the entry.
- Detail pane exposes the full 4-state control for power use.
- Writer MUST round-trip `~/.claude/settings.json` preserving all unknown keys
  (the real file has 13+ keys: env, permissions, hooks, statusLine, …).
  Atomic write, `.bak` before this app's first-ever write.

**Secondary — other tools (Cursor / agents-standard / OpenCode dirs): shelving.**
No override map exists there. Per-tool switches in the detail pane move the
folder to `~/Library/Application Support/Skillbox/shelf/<tool-id>/<dirName>`
and back (same-volume rename, never copy/delete; collision on restore →
surface error, never overwrite). Cross-reads exist (OpenCode also reads
`~/.claude/skills` and `~/.agents/skills`) — detail pane states this plainly.

Metadata: `addedAt` = dir `.creationDate`; `touchedAt` = max(SKILL.md mtime,
dir mtime); `source` = "Managed" badge if dirName appears in the (hidden)
registry lockfile, else "Local".

This Mac's ground truth (verified): all four skills dirs exist; 51 dirs in
`~/.claude/skills`; prompt files present: `~/.claude/CLAUDE.md`,
`~/.codex/AGENTS.md`. No `skillOverrides` key yet.

## 3. Architecture changes

### SkillboxKit (new/changed)
- `SkillInventory` — scans all target skills dirs + shelf → `[InstalledSkill]`:
  identity `dirName`; fields: name, description, frontmatter extras, per-tool
  presence (active/shelved/absent), addedAt, touchedAt, isManaged.
- `ClaudeSettingsStore` — reads/writes `skillOverrides` in
  `~/.claude/settings.json`, preserving unknown keys; atomic; one-time `.bak`.
- `SkillShelf` — shelve/restore folder moves for non-Claude tools.
- `PromptFileStore` — discover/read/write global prompt files from a
  candidate list, create-if-missing for canonical paths, atomic writes.
- Existing sync engine (GitClient/CatalogScanner/Planner/Installer) untouched,
  no longer reachable from UI.
- Tests: inventory scan, shelve/restore round-trip incl. collisions, prompt IO.

### App target (rebuilt state layer)
- Kill the `AppState` god-object. Replace with `@Observable @MainActor` models:
  - `SkillLibraryModel` — inventory, activation, search/filter, refresh (FSEvents
    or on-focus refresh).
  - `PromptEditorModel` — load/save/dirty state per prompt file.
  - `AppServicesModel` — update checker, launch-at-login, log access.
- Modern SwiftUI per swiftui-expert-skill: `@Observable` (not ObservableObject),
  `@State private`, `.task`/`.task(id:)` instead of Timer/DispatchQueue,
  `.animation(_:value:)`, stable ForEach identity, extracted subviews.
- Delete: OnboardingView (~550 loc), registry Settings UI, sync menu UI,
  gh-auth auto-fix flow, setup-check UI, sync analytics events. Keep the Kit
  services for team-mode-later.

### File layout (no grab-bag files, nothing near 500+ lines)
```
Sources/Skillbox/
  App/            SkillboxApp, AppDelegate, WindowCoordinator, main
  Design/         Theme (tokens), components (Card, Switch row, Badge, EmptyState)
  Models/         SkillLibraryModel, PromptEditorModel, AppServicesModel, Analytics
  Views/Library/  LibraryWindow, Sidebar, SkillList, SkillRow, SkillDetail
  Views/Prompts/  PromptEditor
  Views/MenuBar/  MenuPopover
  Views/Settings/ SettingsWindow (tools status, launch at login, updates, logs)
```

## 4. Design language — "quiet desk" (Codex-app-inspired)

- **Canvas**: warm paper neutral (light: #FAF9F7; dark: #1C1B19-ish warm
  charcoal), no pure white/black. Content floats on soft cards (12pt radius,
  hairline 0.5pt border at 6-8% primary, shadow only on hover/detail).
- **Type**: SF Pro; 13pt body, 11pt secondary, small-caps 10pt section labels
  with tracking; monospaced for paths.
- **Color**: monochrome ink hierarchy + ONE accent (warm amber-green? pick:
  `#C96442`-family terracotta reads "Codex"; final call at implementation)
  used only for active switches, selection tint, and the icon.
- **Motion**: `.snappy` springs on toggle/selection; row press scale 0.98;
  detail pane cross-fade+slide 150ms; zero layout jank — all IO off-main,
  list appears instantly from cache then refreshes.
- **Density**: generous — 44pt rows, 20-24pt gutters, no separators between
  rows (spacing + hover wash instead).
- **Icon**: new — rounded-rect, warm paper field, embossed/inset open-box glyph
  with the accent, flat (no gloss), looks native next to Codex/Claude icons.

## 5. Quality pass (/improve targets)

- Remove CRUD & ceremony: UserDefaults scatter → one `PersistedFlags` type;
  duplicated Task.detached+MainActor.run blocks → small `async` helpers;
  logger closures threaded 5 layers deep → structured logging via one type.
- Kill dead code from v1: onboarding, setup checker UI paths, sync diagnostics
  surface, Hypersync-era compatibility branches, IconGenerator CLI leftovers
  (keep --generate-icon, it's used by packaging).
- Long files: BrowserView.swift (466) and OnboardingView.swift (~700) die in
  the restructure; nothing new above ~250 lines.
- Naming: no "Hyper"/"sync-first" vocabulary in user-facing strings.

## 6. Execution split

- **Me (Fable)**: design system, all SwiftUI views, models' shape, icon, final
  review of every diff, commits.
- **codex gpt-5.6-sol xhigh**: SkillboxKit engine work (SkillInventory,
  SkillActivator, PromptFileStore + tests) from a precise brief; mechanical
  deletions/moves; adversarial plan+code review (≤3 turns); computer-use E2E
  validation of the packaged app at the end.
- Gate: I run `swift build` + `swift test` after every codex diff; codex never
  commits.

## 7. Verification

1. `swift test` — engine + new inventory/activator/prompt tests green.
2. Package + launch; menu bar and library render with real skills from this Mac.
3. Toggle a skill off → folder moves to shelf; Claude Code session no longer
   lists it; toggle on → restored. (Verified on a scratch skill, not user data.)
4. Prompt edit round-trip: edit CLAUDE.md in app → file on disk updated (backup
   `.bak` written before first save of a session).
5. codex computer-use E2E: drive the packaged app, screenshot library, prompts
   editor, toggle flow; written pass/fail report + screenshots.

---

## 8. Review decision log (codex xhigh, turn 1 → resolutions)

Accepted as-is: #1 contract unification (this doc + GOAL.md now authoritative:
Claude = skillOverrides only, folder never moves; others = shelving), #3
fail-closed settings writer (leaf-level patch, preserve POSIX mode, refuse
malformed, non-overwriting .bak, full test matrix), #6 prompt-file set
(~/.claude/CLAUDE.md + ~/.codex/AGENTS.md canonical; others listed if present).

Accepted, reduced for v2:
- #2 settings race → all Skillbox mutations serialize through one actor;
  each mutation re-reads latest bytes, patches one leaf, verifies the file
  stat (mtime+size) captured at read hasn't changed before rename, bounded
  retry ×3. No cross-process lock (Claude's watcher tolerates our atomic
  replace; losing a sub-ms race to the /skills TUI is accepted).
- #4 mixed states → the list switch is explicitly scoped "Active for Claude"
  in UI copy; rows show a divergence indicator when other tools differ;
  per-tool truth lives in the detail pane. No 5-state aggregate machine.
- #5 symlinks → scanner uses lstat semantics (dir / valid link / broken link);
  metadata read through resolved targets; **shelving refuses symlinks** (UI
  disables the switch with a "Symlinked" chip — Claude override still works,
  which is the primary control anyway).
- #9 watching → one DirectoryMonitor (DispatchSource) on the four skills
  roots + ~/.claude + prompt parents; 300ms coalescing; refresh backstop on
  app-active. Symlink-target parents not watched (documented limitation).
- #11 metadata honesty → labels are "Folder created" and "Updated"
  (SKILL.md/dir mtime approximation); frontmatter chips from a typed
  allowlist only (model, disable-model-invocation, argument-hint).
- #12 in-flight ops → per-skill `mutating` set disables its controls;
  state publishes only after post-mutation re-scan; errors surface inline.
- #13 dormant sync → SyncService declared non-runnable in v2 (no UI path,
  guard comment); shelf-aware Planner is a team-mode prerequisite, deferred.
- #15 design vs native → sidebar keeps native vibrancy (canvas tint only on
  content/detail columns); sidebar rows native height; no row press scaling
  (press scale only on buttons); Reduce Motion respected via system springs.

Rejected, with reasons:
- #7 full SkillInstallation identity model — dirName grouping stands for v2;
  divergent same-name content across tools is rare and visible in the detail
  pane's per-tool paths. Revisit with team mode.
- #8 Kit command actor + model split — single shared SkillLibraryModel is
  already app-scoped and injected everywhere; the settings actor (#2) is the
  only new serialization point v2 needs.
- #14 drop PostHog / drop previous-instance termination — analytics is an
  explicit user decision (keep); instance replacement is deliberate v1
  behavior (graceful terminate()), kept.
