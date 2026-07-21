# Skillbox Registry Template

Template repository for [Skillbox](https://github.com/ovsh/skillbox) — a macOS menu-bar skill manager that installs shared AI agent skills and rules across your team's tools.

Skillbox distributes your registry to **Claude Code, Cursor, OpenCode**, and any tool that reads the shared `~/.agents/` directory — all from a single Git repo, with per-skill install toggles.

## Getting Started

1. Click **Use this template** on GitHub to create your team's registry repo
2. Edit the files under `everyone/` to add org-wide skills and rules
3. Commit and push to `main`
4. Share the repo URL with your team — they'll paste it in Skillbox's setup wizard

## Structure

```
everyone/                    # Org-wide skills & rules
  skills/                    # One directory per skill, each with a SKILL.md
  rules/                     # Markdown rule files
  playground/                # Experimental skills (opt-in per person)
    skills/
```

### Multiple spaces

Any top-level folder containing `skills/` or `rules/` is discovered as a space:

```
everyone/                    # Org-wide
engineering/                 # Engineering-specific skills
product/
CODEOWNERS                   # Governance
```

Optional metadata per space in a `space.yaml`:

```yaml
name: Engineering
description: Skills for the engineering team
```

## Skills

Each skill is a directory with a `SKILL.md` describing it:

```markdown
---
name: Code Review
description: Reviews diffs against our team checklist
---

Instructions for the agent go here…
```

Everything in the skill directory syncs with it (scripts, references, templates).

## Playground

Skills in `playground/skills/` are **off by default** — team members opt in per skill from the Skillbox app. To promote one to official, move it to `skills/` via a pull request.
