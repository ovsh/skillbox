# Skillbox v2 — Goal

When this is done, Skillbox is **the user's personal skill manager**: an always-on,
beautiful, buttery-smooth menu bar app that answers "what skills do my AI tools
have, are they on, and what's my agent actually being told?"

## Definition of done

1. **Single-player.** All team/registry/space UI is hidden. No GitHub required to
   get value. The app opens straight into *my skills on this Mac*.
2. **See every skill** across Claude Code (`~/.claude/skills`), the agents
   standard (`~/.agents/skills`), Cursor, and OpenCode — with real metadata:
   active or not, when it was added, when it was last touched, which tools have it.
3. **Activate / deactivate per skill** with one switch, using the mechanism each
   tool actually respects (researched, not assumed): for Claude Code + Agent
   SDK the switch writes the sanctioned `skillOverrides` map in
   `~/.claude/settings.json` — the skill folder never moves. For tools without
   an override map (Cursor / agents dir / OpenCode), per-tool switches shelve
   the folder losslessly; symlinked skills are never moved.
4. **Inline prompt editing.** `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`
   (the "main agent prompt") are visible and editable in place, with save
   guarded against overwriting concurrent on-disk edits.
5. **Codex-app design language.** New design system (calm, light, generous
   spacing, subtle materials, smooth 60fps transitions) + a new app icon.
   No lag: skill list scan is async, markdown rendering never blocks the UI.
6. **Code quality bar.** /improve pass executed; CRUD and noise removed; no
   grab-bag long files; SwiftUI best practices; adversarially reviewed by
   codex gpt-5.6 (xhigh) with convergence in ≤3 turns.
7. **Verified working.** `swift build` + `swift test` green, app packaged,
   launched, and E2E-validated (codex computer-use) with screenshots as proof.
8. **Team mode later.** The sync engine (SkillboxKit) stays intact underneath;
   registry sync is simply not surfaced in the UI yet.
