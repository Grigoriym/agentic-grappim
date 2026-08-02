---
name: finalize
description: Wrap up a work session by capturing what was learned into the places
  future sessions will actually read — the project's CLAUDE.md and docs, persistent
  memory, and, when the lesson is not project-specific, the shared skills in
  agentic-grappim itself. Use when the user says "finalize", "wrap up", "update the
  docs with what we learned", or at the end of a session that produced non-obvious
  knowledge.
metadata:
  author: grappim
  keywords:
  - finalize
  - wrap up
  - end of session
  - update docs
  - capture learnings
  - improve the shared skills
---

Run at the end of a work session. The goal is that a future session starting cold
knows what this session learned, without the user having to re-explain it.

This skill is installed for the user account, so it runs in **every** project. Two
things get written: the current project, and — when the lesson isn't project-specific
— the shared setup in `agentic-grappim` that produced this skill.

## Step 0. Where you may write

`~/.claude/skills/` and `~/.claude/agents/` are symlinks into the
`agentic-grappim` checkout, so **editing a shared skill changes behaviour in every
project**. That is allowed and is half the point of this skill: the process is
supposed to get better every session. It is not a thing to ask permission for each
time.

What keeps it safe is the repo, not a queue:

- `agentic-grappim` is a git checkout. **Leave the edit uncommitted.** The user
  reviews it with `git diff` and drops it with `git checkout --`. The diff is the
  proposal; there is no separate proposal document.
- **Never edit a shared skill for a single-project fact.** One occurrence in one
  project is project knowledge — it goes in that project's `CLAUDE.md` or docs. A
  shared edit needs a reason that would still hold in a project you haven't seen.
- Say what you changed there, in the Step 5 report. A silent edit to a shared skill
  is the one genuinely bad outcome.

If the current project *is* `agentic-grappim`, this is its own maintenance session —
edit `skills/`, `agents/` and `README.md` freely, and commit as the user asks.

## Step 0.5. Read the project's own close-out

Before harvesting, check the current project's `CLAUDE.md` for a documented close-out
procedure or docs discipline — a plan document, an ADR directory, a decision log, a
deviations table. If one exists:

- **Its docs are routing destinations**, alongside `CLAUDE.md` and memory. A
  structural decision belongs in the architecture doc; a per-step surprise in the log;
  only a *convention* in `CLAUDE.md`.
- **Read what that procedure already wrote this session.** Finalize often runs after
  the project's own fold, and the fastest way to produce a duplicate is to skip this.
- **Its standing instructions win** where they conflict with this skill — most often
  about committing (Step 5).

A project with no such procedure routes exactly as Step 3 says.

## Step 1. Harvest

Re-read the session and list every fact that was **learned**, not just done. Two kinds
matter, and the second is the one that gets forgotten.

**Things** — what the code and tools turned out to be:

- Something that surprised you or cost more than one attempt to get right.
- A build/tooling gotcha (Gradle, AGP, KSP, Koin, CI) and its workaround.
- A convention in the project that isn't obvious from reading the code.
- A version constraint or compatibility pin discovered the hard way.
- A command sequence that worked and will be needed again.
- An external resource that turned out to matter (docs page, issue, dashboard).

**Process** — how the work went, which is what makes the next session better:

- Something that nearly shipped wrong, **and what actually caught it**. Name the
  check: a screenshot, a test, a review pass, the user. If nothing would have caught
  it but luck, that is the finding.
- A claim in the project's own docs or an earlier step's notes that turned out to be
  false, or true in intent but not implemented.
- A correction the user made to your approach, and the reason behind it.
- An order of work that mattered — something cheap that had to happen before
  something expensive, or a verification that only meant anything from a clean state.
- A real problem you saw and deliberately left alone to keep the diff honest. This is
  knowledge too, and it is the kind most often lost — "not fixed" reads as "nothing to
  record", so it dies with the session instead of reaching the routing table.

Write the raw list first. Filtering comes next — do not filter while harvesting.

## Step 2. Filter

Drop an item if **any** of these hold:

- The code, tests, or git history already say it. Fixes that landed as commits are
  already recorded; don't restate them.
- It only mattered inside this session (a one-off path, a temp file, a debugging
  detour that led nowhere).
- It's textbook knowledge with no local twist — how `git rebase` works, what a
  `data class` is.
- It's already written in the destination file. Check first, including the shared
  skill you'd be editing, so you don't write it twice.

**Do not drop a process finding for being "obvious".** A near-miss reads as obvious
precisely because you now know the answer; the next session won't. If a check caught
something a reasonable session would have shipped, that is worth writing down even
when the underlying fact is mundane.

If nothing survives the filter, say so plainly and stop. An empty finalize is a valid
outcome; do not manufacture updates.

## Step 3. Route

| What it is | Where it goes |
|---|---|
| Convention, gotcha, or constraint specific to this project | project `CLAUDE.md` |
| A fact the project designates a doc for (architecture, decisions, deviations) | that doc (Step 0.5) |
| Technique, procedure, or working habit that applies across projects | the shared skill in `agentic-grappim` |
| User's working style, or a correction with a why | memory (`user` / `feedback`) |
| Ongoing goal or constraint not derivable from the repo | memory (`project`) |
| External URL that will be needed again | memory (`reference`) |
| A real problem seen and deliberately **not** fixed | the project's deferred/backlog doc — create one if absent |

`CLAUDE.md` is the default **for conventions and gotchas**. Where the project
designates a doc for a kind of fact, that doc wins for that kind — an architecture
decision in `CLAUDE.md` is as misfiled as a build command in an ADR.

A shared edit needs generality, not just usefulness: it came up in more than one
project, or it clearly would. A single occurrence is a project fact.

Memory is per-project and won't follow the user elsewhere, so it is never the right
home for cross-project knowledge — that's what the shared skills are for.

## Step 4. Apply

- **Docs this session invalidated**: if the work falsified a claim in an existing
  project doc, correcting that doc is part of finalize, not a follow-up. A fix that
  lands while a doc still reports the problem as open leaves the doc actively
  misleading, and the next session will cite it as current.
- **`CLAUDE.md` and project docs**: add to the section that covers the topic; only
  create a new section when none fits. Match the file's existing voice.
- **Memory**: one file per fact, plus a one-line pointer in `MEMORY.md`. Update an
  existing memory rather than adding a second one on the same subject.
- **Shared skill**: edit the `SKILL.md` under `~/.claude/skills/<name>/` (which is the
  `agentic-grappim` checkout). Keep it short — a skill that grows a paragraph every
  session stops being read. Prefer sharpening an existing rule over adding a new one,
  and delete a rule that this session proved wrong. If it affects what the skill is
  *for*, update its `description` frontmatter and the table in the repo's `README.md`
  too. Leave it uncommitted.

## Step 5. Report

Short summary:

- what changed in the project,
- what went to memory,
- **what changed in the shared skills** — file plus one line on the behaviour change,
  so the user can `git diff` it in `agentic-grappim` before it reaches other projects,
- what was harvested but deliberately dropped, one line each.

The user needs to be able to disagree with your filtering.

Do not commit or push unless the user asks — **unless the project's own close-out
procedure (Step 0.5) says to, which is a standing instruction and counts as asking.**
That applies to the project. Shared-skill edits stay uncommitted regardless.
