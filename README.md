# agentic-grappim

Shared agent skills and templates for grappim projects. Changes here are immediately available in all linked projects — no sync step needed.

## Projects using this repo

| Project | Path |
|---------|------|
| MealieMobile | `../MealieMobile/.claude/` |
| TaigaMobileNova | `../TaigaMobileNova/.claude/` |

Each project symlinks into this repo:
```
.claude/skills/navigation-3  →  ../../../../agentic-grappim/skills/navigation-3
.claude/templates/spec.md    →  ../../../../agentic-grappim/templates/spec.md
```

## Contents

### `skills/`

Agent skills loaded automatically by Claude Code and other compatible agents.

| Skill | Description |
|-------|-------------|
| `navigation-3` | Google's official Navigation 3 recipes — basic API, Koin integration, deep links, scenes, conditional nav, passing arguments, returning results |

Source: [google/android-skills](https://github.com/google-ai-edge/gallery) — official Google repo.

### `templates/`

| Template | Usage |
|----------|-------|
| `spec.md` | Feature spec — fill in before starting a feature, save next to the feature module |

## Adding a new skill

1. Add the skill folder to `skills/`:
   ```
   skills/
     my-skill/
       SKILL.md
       references/   (optional)
   ```
2. Symlink it into each project:
   ```bash
   ln -s ../../../../agentic-grappim/skills/my-skill ProjectName/.claude/skills/my-skill
   ```
3. Commit in both repos.

## Adding a new project

```bash
mkdir -p NewProject/.claude/skills NewProject/.claude/templates
ln -s ../../../../agentic-grappim/skills/navigation-3 NewProject/.claude/skills/navigation-3
ln -s ../../../../agentic-grappim/templates/spec.md NewProject/.claude/templates/spec.md
```

> Symlinks assume all projects live as siblings under the same parent directory (`grappim/`).