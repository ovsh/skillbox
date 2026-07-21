# Skillbox

Menu-bar macOS skill manager for AI coding tools. Connect a GitHub registry repo, browse its skills, and toggle each one on or off — Skillbox installs them into every tool on your Mac and keeps them in sync.

Skillbox is the ground-up rewrite of Hypersync, rebuilt around skills as the primary object instead of repo syncing.

## Install

1. Download **Skillbox-MacOS.zip** from the [latest release](../../releases/latest)
2. Unzip and move **Skillbox.app** to `/Applications`
3. Open Skillbox — it lives in your menu bar
4. Connect an existing registry or **one-click create** one from the template, then pick your skills

> Requires macOS 14+.

## What it manages

Skillbox discovers `skills/` and `rules/` directories in your registry repo and installs them into every detected tool:

| Tool | Skills | Rules | Detected via |
|------|:------:|:-----:|---|
| Agents standard (Codex, Windsurf, Gemini CLI, …) | `~/.agents/skills` | — | always on |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `~/.claude/skills` | `~/.claude/rules` | `~/.claude` |
| [Cursor](https://cursor.sh) | `~/.cursor/skills` | `~/.cursor/rules` | `~/.cursor` |
| [OpenCode](https://opencode.ai) | `~/.config/opencode/skills` | — | `~/.config/opencode` |

Need another tool? Add a `Target` to `Sources/SkillboxKit/Targets.swift`.

## How it differs from a plain sync

Every file Skillbox writes is recorded in a **lockfile**. That's what makes it a manager rather than a copier:

- **Per-skill toggles** — flip any skill on/off; off means its files are removed from every tool on the next sync
- **Clean uninstalls & pruning** — skills deleted or renamed in the registry are removed locally, including emptied directories
- **Local skills stay untouched** — anything Skillbox didn't install, it never deletes
- **Playground opt-in** — skills under `playground/skills/` are off by default, per-person opt-in
- **Tool auto-detection** — files only go to tools that exist on the machine (overridable per tool in Settings)

## Registry layout

Either top-level `skills/` + `rules/`, or space folders (any top-level directory containing them):

```
everyone/
  skills/<skill-name>/SKILL.md
  rules/*.md
  playground/skills/<skill-name>/SKILL.md
engineering/
  skills/…
```

Optional `space.yaml` per space provides `name:` and `description:`. See [skillbox-template](skillbox-template/) for a starter registry.

## Features

- **Skills browser** — three-pane window: spaces, skill list with install switches, markdown detail
- **One-click sync** from the menu bar; toggles auto-sync after a short debounce
- **Auto sync** on a configurable interval
- **Onboarding wizard** — GitHub CLI install/auth flow, create-from-template or connect existing
- **Setup check** — diagnoses git/SSH/credential problems with actionable fixes
- **Auto-update** — checks GitHub Releases and self-updates in place
- **Launch at login** (on by default; toggle in Settings)

## Building from source

Requires Xcode 16+ (Swift 6) and macOS 14+.

```bash
# Debug build + tests
swift build
swift test

# Release build + app bundle (ad-hoc signed, no notarization)
CODESIGN_IDENTITY="-" SKIP_NOTARIZE=1 ./scripts/package_app.sh
```

The app bundle lands at `dist/Skillbox.app`.

### Signed + notarized (for distribution)

```bash
# One-time: store notarization credentials
xcrun notarytool store-credentials "Skillbox" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID" \
  --password "YOUR_APP_SPECIFIC_PASSWORD"

# Build, sign, notarize
VERSION=0.1.0 ./scripts/package_app.sh
```

### Install locally

```bash
./scripts/install_app.sh
```

## Releasing

```bash
./scripts/release.sh v0.1.0
```

Tags the commit and pushes. GitHub Actions builds, signs, notarizes, and publishes a release with DMG + ZIP.

## Architecture

- **SkillboxKit** — pure, UI-free engine: `GitClient` → `CatalogScanner` → `Planner` → `Installer`, with the lockfile (`LockfileStore`) as the source of truth for what's managed. Fully covered by `swift test`.
- **Skillbox** (app) — SwiftUI menu bar app + browser/settings/onboarding windows over the Kit.

## Data

| Item | Path |
|---|---|
| Settings | `~/Library/Application Support/Skillbox/settings.json` |
| Lockfile | `~/Library/Application Support/Skillbox/lockfile.json` |
| Logs | `~/Library/Application Support/Skillbox/sync.log` |
| Registry checkout | `~/Library/Application Support/Skillbox/registry` |

## License

MIT
