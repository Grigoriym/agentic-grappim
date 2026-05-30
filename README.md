# agentic-grappim

Shared agent skills and templates for grappim projects.

## Projects using this repo

| Project | Path |
|---------|------|
| MealieMobile | `../MealieMobile/` |
| TaigaMobileNova | `../TaigaMobileNova/` |
| HateItOrRateIt | `../HateItOrRateIt/` |

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
      adaptive              → ../agentic-grappim/skills/adaptive
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
| `adaptive` | Adaptive layouts for phones, tablets, foldables — window size classes, FlexboxLayout, Grid, MediaQuery, list-detail |
| `agp9` | Upgrades an Android project to Android Gradle Plugin version 9 (not for KMP projects) |

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

Run these commands from inside the new project's root directory:

```bash
# 1. Add the submodule
git submodule add https://github.com/Grigoriym/agentic-grappim.git .claude/agentic-grappim

# 2. Create skill and template symlinks
mkdir -p .claude/skills .claude/templates
ln -s ../agentic-grappim/skills/adaptive      .claude/skills/adaptive
ln -s ../agentic-grappim/skills/edge-to-edge  .claude/skills/edge-to-edge
ln -s ../agentic-grappim/skills/navigation-3  .claude/skills/navigation-3
ln -s ../agentic-grappim/templates/spec.md    .claude/templates/spec.md

# 3. Commit
git add .gitmodules .claude/
git commit -m "migrate shared skills to git submodule"
```

Then add a **Skills** section to the project's `CLAUDE.md`:

```markdown
## Skills

Skills live in `.claude/skills/`. Shared skills come from the `agentic-grappim` git submodule at `.claude/agentic-grappim/`.

**After cloning**, initialize the submodule to make shared skills available:
\`\`\`bash
git submodule update --init
\`\`\`

| Skill | Usage | Description |
|-------|-------|-------------|
| `navigation-3` | Reference skill (auto-loaded) | Google's official Navigation 3 recipes |
| `edge-to-edge` | Reference skill (auto-loaded) | System bars, insets, IME handling for SDK 35+ |
| `adaptive` | Reference skill (auto-loaded) | Adaptive layouts for tablets/foldables — window size classes, list-detail, FlexboxLayout |
```

Finally, add the project to the [Projects using this repo](#projects-using-this-repo) table above.