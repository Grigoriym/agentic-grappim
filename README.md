# agentic-grappim

Shared Claude Code skills and agents for grappim projects.

## How it's wired

**Per project, not per user account.** A project opts in by symlinking the skills it
wants into its own `.claude/skills/`. Claude Code follows a symlink there and reads
`SKILL.md` from the target, so the skill still lives in this repo and a `git pull` here
updates every project that links it.

Nothing is installed into `~/.claude/skills/`. That would make every skill visible in
**every** session — including unrelated repos — and each one's `description` is loaded
into context whether or not it is ever used. Scoping per project keeps that cost where
the skill is actually wanted.

The links are **relative**, so they resolve on any machine where the repos are siblings
and can be committed to the project:

```
<project>/.claude/skills/finalize -> ../../../agentic-grappim/skills/finalize
```

## Setup (new machine / fresh clone)

```bash
git clone https://github.com/Grigoriym/agentic-grappim.git ~/proj/grappim/agentic-grappim

# agents are still per account — there is no per-project agents symlink convention yet
mkdir -p ~/.claude/agents
ln -s ~/proj/grappim/agentic-grappim/agents/koin-expert.md ~/.claude/agents/koin-expert.md
```

Then, in each project that wants them:

```bash
cd ~/proj/grappim/<project>
mkdir -p .claude/skills
for s in bro finalize investigate-issue masvs-review update-gradle-wrapper; do
  ln -s ../../../agentic-grappim/skills/$s .claude/skills/$s
done
```

**Never copy this repo into a project.** A stale copy still resolves, so its skills keep
working while silently serving old content — the same failure mode as a duplicated
agent. Link, don't vendor.

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
   Add **`disable-model-invocation: true`** — every skill here is manual-only, invoked
   as `/<name>` and never auto-triggered. It also keeps the description out of context
   in every unrelated session.
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

## Third-party content

The repo is Apache-2.0, with one exception worth knowing before you copy anything out of it:

| File | Contains | Licence |
|---|---|---|
| `skills/masvs-review/references/masvs-controls.md` | the 24 MASVS v2 control statements, quoted verbatim | © OWASP Foundation, [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |

The commentary around those quotes is ours. Nothing here is derived from any third-party
skill collection — the control text comes from OWASP's own `OWASP_MASVS.yaml`, and the
MASTG test mapping is read live from the OWASP repo rather than copied.

## Projects using these skills

| Project | Path |
|---------|------|
| MealieMobile | `../MealieMobile/` |
| TaigaMobileNova | `../TaigaMobileNova/` |
| HateItOrRateIt | `../HateItOrRateIt/` |

Listed for reference only — no wiring lives in these projects.
