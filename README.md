# agentic-grappim

Shared Claude Code skills and agents for grappim projects.

## How it's wired

The skills and agents here are installed **once for the user account**, not per
project. Claude Code reads `~/.claude/skills/` and `~/.claude/agents/` in every
session, whatever directory you're working in — so anything installed there is
available in all projects automatically, including new ones.

There is nothing to add to a project to make these available.

## Setup (new machine / fresh clone)

```bash
git clone https://github.com/Grigoriym/agentic-grappim.git ~/proj/grappim/agentic-grappim

mkdir -p ~/.claude/skills ~/.claude/agents

ln -s ~/proj/grappim/agentic-grappim/skills/finalize              ~/.claude/skills/finalize
ln -s ~/proj/grappim/agentic-grappim/skills/investigate-issue     ~/.claude/skills/investigate-issue
ln -s ~/proj/grappim/agentic-grappim/skills/update-gradle-wrapper ~/.claude/skills/update-gradle-wrapper
ln -s ~/proj/grappim/agentic-grappim/agents/koin-expert.md        ~/.claude/agents/koin-expert.md
```

Symlinks mean a `git pull` here updates every project at once. Copies work too, but
then each update has to be re-copied.

## Contents

### `skills/`

| Skill | Description |
|-------|-------------|
| `finalize` | End-of-session wrap-up — captures what was learned into the project's `CLAUDE.md` and memory; anything reusable becomes a proposal doc in `.claude/proposals/` for review here |
| `investigate-issue` | Investigation-first process for bug reports — evidence-based root cause, an investigation doc in `docs/issues/`, options with tradeoffs, then a stop for the user's decision before any code |
| `update-gradle-wrapper` | Updates the Gradle wrapper to a given version, fetching the SHA-256 checksum from Gradle's distribution server |

### `agents/`

| Agent | Description |
|-------|-------------|
| `koin-expert` | Koin DI expert for TaigaMobileNova KMP — diagnoses `NoBeanDefinitionException`, broken expect/actual `@Configuration`, missing module wiring, and `KoinGraphTest` failures |

## Adding a skill

1. Create `skills/<name>/SKILL.md` with `name` and `description` frontmatter. Long
   reference material goes in `skills/<name>/references/`, not in `SKILL.md`.
2. Link it in: `ln -s ~/proj/grappim/agentic-grappim/skills/<name> ~/.claude/skills/<name>`
3. Add a row to the table above, and commit.

A skill must be a folder containing `SKILL.md`. A loose `.md` file in `skills/` will
not be picked up.

## Proposals

The `finalize` skill never edits this repo from another project — editing a linked
skill in place would silently change behaviour everywhere. Instead it writes
`.claude/proposals/<date>-<slug>.md` in whichever project it ran in.

When working here, check those directories for proposals waiting to be applied:

```bash
ls ~/proj/grappim/*/.claude/proposals/ 2>/dev/null
```

## Projects using these skills

| Project | Path |
|---------|------|
| MealieMobile | `../MealieMobile/` |
| TaigaMobileNova | `../TaigaMobileNova/` |
| HateItOrRateIt | `../HateItOrRateIt/` |

Listed for reference only — no wiring lives in these projects.
