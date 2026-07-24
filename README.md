# Loadout

Menu-bar macOS skill manager for your AI coding tools. See every skill installed on your Mac, flip each one on or off for Claude Code and the Agent SDK, and edit your global agent prompts (CLAUDE.md, AGENTS.md) inline — in an always-on, quiet little app.

A loadout is the gear you take into a match. This is where you equip your agents.

> Formerly **Skillbox**. The GitHub repo keeps the old slug; the app, bundle id (`com.ovsh.loadout`), and everything user-facing are Loadout. Requires macOS 14+.

## What it does

- **Library** — every skill across `~/.claude/skills`, `~/.agents/skills`, `~/.cursor/skills`, and `~/.config/opencode/skills` in one list, with when it was added, when it last changed, and which tools see it.
- **One switch per skill** — writes Claude Code's sanctioned `skillOverrides` map in `~/.claude/settings.json` (`on` / `name-only` / `user-invocable-only` / `off`). Claude Code file-watches it, so toggles apply to live sessions, and it governs Agent SDK apps too. The skill's folder never moves.
- **Per-tool shelving** — tools without an override map (Cursor, the agents dir, OpenCode) get per-tool switches that move the folder to Loadout's shelf and restore it losslessly. Symlinked skills are never moved.
- **Prompt editor** — `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` editable in place, with autosave that never clobbers concurrent on-disk edits.
- **Always current** — directory watchers keep the library and menu bar in sync with whatever your tools or a `git pull` do to your skills.

Safety posture: Loadout backs up `settings.json` before its first write, patches only the one key it owns, preserves file permissions, and never deletes or overwrites skill content — deactivation is always reversible.

## Building from source

Requires Xcode 16+ (Swift 6) and macOS 14+.

```bash
swift build && swift test

# Release app bundle (ad-hoc signed, no notarization)
CODESIGN_IDENTITY="-" SKIP_NOTARIZE=1 ./scripts/package_app.sh
```

The app bundle lands at `dist/Loadout.app`. `./scripts/install_app.sh` installs to `~/Applications`.

### Releasing

```bash
./scripts/release.sh v0.5.0
```

GitHub Actions builds, signs, notarizes, and publishes DMG + ZIP. The app self-updates from GitHub Releases.

## Architecture

- **LoadoutKit** — UI-free engine, fully covered by `swift test`:
  `SkillInventoryScanner` (unified inventory incl. symlink handling) ·
  `ClaudeSettingsStore` (fail-closed `skillOverrides` writer) ·
  `SkillShelf` (lossless folder shelving) · `PromptFileStore` (revision-guarded prompt IO).
  The registry-sync engine (git → catalog → plan → install) from v1 remains in
  the Kit for a future team mode, with no UI in v2.
- **Loadout** (app) — SwiftUI menu bar app; `@Observable` models over the Kit;
  "Graphite" design system (near-black instrument neutrals, color only where
  state lives).

## Data

| Item | Path |
|---|---|
| Shelved skills | `~/Library/Application Support/Loadout/shelf/<tool>/` (a `Skillbox` dir from older versions is migrated automatically) |
| Settings backup | `~/.claude/settings.json.loadout.bak` (created once; an existing `.skillbox.bak` is honored) |
| Logs | `~/Library/Application Support/Loadout/sync.log` |

## Website

The landing page's source of truth is `site/` in this repo, but it deploys from
the personal-website repo (`~/Documents/code/personal-website/loadout/`, served
at ovsh.github.io/loadout/ — one deploy for the whole personal site). After any
`site/` change, run `scripts/sync-site.sh` and commit both repos.

## License

MIT
