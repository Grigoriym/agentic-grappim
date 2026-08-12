# agentic-grappim

Shared Claude Code skills and agents for grappim projects.

## How it's wired

A skill lives in this repo; a machine opts in by symlinking it from either
`~/.claude/skills/` (every project on that machine sees it) or a given project's own
`.claude/skills/` (only that project does). Claude Code follows either symlink and reads
`SKILL.md` from the target, so a `git pull` here updates everywhere it's linked, no
matter which style a given machine uses. This repo doesn't mandate one — different
machines running it may wire it differently; pick whichever fits and stay consistent on
that machine.

A project-scoped link is **relative**, so it resolves on any machine where the repos are
siblings and can be committed to the project:

```
<project>/.claude/skills/finalize -> ../../../agentic-grappim/skills/finalize
```

A user-account link is machine-local (typically absolute) and isn't committed anywhere.

## Setup (new machine / fresh clone)

```bash
git clone https://github.com/Grigoriym/agentic-grappim.git ~/proj/grappim/agentic-grappim

# agents are still per account — there is no per-project agents symlink convention yet
mkdir -p ~/.claude/agents
ln -s ~/proj/grappim/agentic-grappim/agents/koin-expert.md ~/.claude/agents/koin-expert.md
```

Then, either every project on the machine:

```bash
mkdir -p ~/.claude/skills
for s in bro finalize investigate-issue masvs-review update-gradle-wrapper emulator-testing android-baseline-profile kover-coverage-sweep compose-stability-audit; do
  ln -s ~/proj/grappim/agentic-grappim/skills/$s ~/.claude/skills/$s
done
```

or just the projects that want them:

```bash
cd ~/proj/grappim/<project>
mkdir -p .claude/skills
for s in bro finalize investigate-issue masvs-review update-gradle-wrapper emulator-testing android-baseline-profile kover-coverage-sweep compose-stability-audit; do
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
| `emulator-testing` | Generic adb/`uiautomator` technique for verifying a change on a real Android emulator — screenshots, coordinate scaling, process-death testing — kept package-name-agnostic, with each project's own package id, AVD name and app-specific gotchas maintained in that project's `docs/EMULATOR_TESTING.md` |
| `android-baseline-profile` | Sets up (or diagnoses) an Android Baseline Profile / Macrobenchmark module to remove JIT warm-up jank on cold navigation — the `com.android.test` producer module, `BaselineProfileRule` journeys, and the easy-to-miss "generated but never applied" `profileinstaller` gap |
| `kover-coverage-sweep` | Ranks a Kover-instrumented Kotlin/KMP project's packages by missed branches/lines, reads the XML report without falling for its denominator-noise traps, and recognizes the recurring shapes that mean a residual isn't worth a test (generated code, Composable-blocked branches, an unreachable elvis arm, a no-op-backend lambda) |
| `compose-stability-audit` | Wires up and runs the Compose Compiler's own stability reports, and triages unstable classes/composable parameters — including the common multi-module cause where a domain type reads as `Unstable` everywhere simply because its module never applies the Compose compiler plugin |

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
2. Link it in, either style (see "How it's wired"): `ln -s
   ~/proj/grappim/agentic-grappim/skills/<name> ~/.claude/skills/<name>`
3. Add a row to the table above, and commit.

**If a skill needs project-specific facts to be useful** (package ids, screen names,
server addresses, an AVD name), keep the skill itself generic and have it read/maintain
a project-local doc for those facts (`docs/security/masvs.md`, `docs/EMULATOR_TESTING.md`)
rather than baking one project's specifics into the skill or duplicating the skill's
generic technique into every project's own doc. `masvs-review` and `emulator-testing`
are the two skills built this way — copy their Step 0 ("read the project doc first, create
it from a template if absent") rather than reinventing the split.

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
| WallosMobile | `../wallosmobile/` |

Listed for reference only — no wiring lives in these projects.
