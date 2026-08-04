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

ln -s ~/proj/grappim/agentic-grappim/skills/bro                   ~/.claude/skills/bro
ln -s ~/proj/grappim/agentic-grappim/skills/finalize              ~/.claude/skills/finalize
ln -s ~/proj/grappim/agentic-grappim/skills/investigate-issue     ~/.claude/skills/investigate-issue
ln -s ~/proj/grappim/agentic-grappim/skills/masvs-review          ~/.claude/skills/masvs-review
ln -s ~/proj/grappim/agentic-grappim/skills/update-gradle-wrapper ~/.claude/skills/update-gradle-wrapper
ln -s ~/proj/grappim/agentic-grappim/agents/koin-expert.md        ~/.claude/agents/koin-expert.md
```

Symlinks mean a `git pull` here updates every project at once. Copies work too, but
then each update has to be re-copied.

## Contents

### `skills/`

| Skill | Description |
|-------|-------------|
| `bro` | Restates the previous message in plain language — no jargon, no preamble, shorter |
| `finalize` | End-of-session wrap-up — captures what was learned into the project's `CLAUDE.md`, its docs and memory; a lesson that isn't project-specific is edited straight into the skill here, uncommitted for review |
| `masvs-review` | Reviews a mobile app against OWASP MASVS v2 from source and maintains the project's security register in `docs/security/masvs.md` — deliberate deviations get recorded once, with their bounds, instead of being re-flagged every run |
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

## How a session improves a skill

The `finalize` skill edits this repo **directly**, from whichever project it runs in —
that is the point of it. A lesson that isn't specific to one project belongs in the
skill, not in a queue of documents waiting to be applied.

What keeps that safe is git, not a gate: the edit is left **uncommitted**, and the
report names the file it touched. Review before it reaches other projects:

```bash
cd ~/proj/grappim/agentic-grappim && git diff
```

Keep or drop it with `git commit` or `git checkout -- .`. A shared edit is supposed to
be rare — one occurrence in one project is that project's knowledge and belongs in its
`CLAUDE.md`.

## Projects using these skills

| Project | Path |
|---------|------|
| MealieMobile | `../MealieMobile/` |
| TaigaMobileNova | `../TaigaMobileNova/` |
| HateItOrRateIt | `../HateItOrRateIt/` |

Listed for reference only — no wiring lives in these projects.
