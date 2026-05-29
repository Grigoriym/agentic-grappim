# agentic-grappim

Shared agent skills and templates for grappim projects.

## Projects using this repo

| Project | Path |
|---------|------|
| MealieMobile | `../MealieMobile/` |
| TaigaMobileNova | `../TaigaMobileNova/` |

## Setup (new machine / fresh clone)

Each project embeds this repo as a git submodule at `.claude/agentic-grappim/`. After cloning a project, run:

```bash
git submodule update --init
```

That's it — all skills and templates resolve automatically via intra-repo symlinks.

## Structure inside each project

```
ProjectName/
  .claude/
    agentic-grappim/        ← submodule (this repo)
    skills/
      edge-to-edge          → ../agentic-grappim/skills/edge-to-edge
      navigation-3          → ../agentic-grappim/skills/navigation-3
    templates/
      spec.md               → ../agentic-grappim/templates/spec.md
```

## Contents

### `skills/`

| Skill | Description |
|-------|-------------|
| `navigation-3` | Google's official Navigation 3 recipes — basic API, Koin integration, deep links, scenes, conditional nav, passing arguments, returning results |
| `edge-to-edge` | System bars, insets, IME handling, safe area padding for Compose apps targeting SDK 35+ |

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
2. In each project, add a symlink into the submodule:
   ```bash
   ln -s ../agentic-grappim/skills/my-skill .claude/skills/my-skill
   git add .claude/skills/my-skill
   ```
3. Commit in both repos.

## Adding a new project

```bash
git submodule add https://github.com/Grigoriym/agentic-grappim.git NewProject/.claude/agentic-grappim
ln -s ../agentic-grappim/skills/navigation-3 NewProject/.claude/skills/navigation-3
ln -s ../agentic-grappim/skills/edge-to-edge NewProject/.claude/skills/edge-to-edge
ln -s ../agentic-grappim/templates/spec.md NewProject/.claude/templates/spec.md
git -C NewProject add .gitmodules .claude/
```