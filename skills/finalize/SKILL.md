---
name: finalize
description: Wrap up a work session by capturing what was learned into the places
  future sessions will actually read — the project's CLAUDE.md, persistent memory,
  and, when something looks reusable across projects, a proposal doc for the shared
  agentic-grappim repo. Use when the user says "finalize", "wrap up", "update the
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
  - propose shared skill
---

Run at the end of a work session. The goal is that a future session starting cold
knows what this session learned, without the user having to re-explain it.

This skill is installed for the user account, so it runs in **every** project. The
project you are in is the one you write to.

## Step 0. The one rule

Write to the current project and to memory. **Do not edit the `agentic-grappim`
repo** — the repo that ships this skill and the other shared ones.

This matters because the shared skills are linked into `~/.claude/`, so editing one
"in place" silently rewrites the shared repo and changes behaviour in every other
project. When something learned here belongs in a shared skill, write a **proposal
doc** (Step 4) and stop there. The user applies it from the `agentic-grappim`
checkout.

The exception: if the current project *is* `agentic-grappim`, you're in its own
maintenance session — edit `skills/`, `agents/`, and `README.md` directly, and check
projects for pending proposals.

## Step 1. Harvest

Re-read the session and list every fact that was **learned**, not just done. Look
specifically for:

- Something that surprised you or cost more than one attempt to get right.
- A correction the user made to your approach, and the reason behind it.
- A build/tooling gotcha (Gradle, AGP, KSP, Koin, CI) and its workaround.
- A convention in the project that isn't obvious from reading the code.
- A version constraint or compatibility pin that was discovered the hard way.
- A command sequence that worked and will be needed again.
- An external resource that turned out to matter (docs page, issue, dashboard).

Write the raw list first. Filtering comes next — do not filter while harvesting.

## Step 2. Filter

Drop an item if **any** of these hold:

- The code, tests, or git history already say it. Fixes that landed as commits are
  already recorded; don't restate them.
- It only mattered inside this session (a one-off path, a temp file, a debugging
  detour that led nowhere).
- It's generic knowledge any competent session would have.
- It's already written in the destination file. Check first, including the relevant
  shared skill, so you don't propose something already documented.

If nothing survives the filter, say so plainly and stop. An empty finalize is a
valid outcome; do not manufacture updates.

## Step 3. Route

| What it is | Where it goes |
|---|---|
| Convention, gotcha, or constraint specific to this project | project `CLAUDE.md` |
| Technique, procedure, or expertise that applies across projects | proposal doc |
| User's working style, or a correction with a why | memory (`user` / `feedback`) |
| Ongoing goal or constraint not derivable from the repo | memory (`project`) |
| External URL that will be needed again | memory (`reference`) |

Default to the project's `CLAUDE.md`. A proposal is for things that came up in more
than one project or are clearly general — a single occurrence is a project fact, not
a shared skill.

Memory is per-project and won't follow the user elsewhere, so it is never the right
home for cross-project knowledge. That's what a proposal is for.

## Step 4. Apply

- **`CLAUDE.md`**: add to the section that covers the topic; only create a new
  section when none fits.
- **Memory**: one file per fact, plus a one-line pointer in `MEMORY.md`. Update an
  existing memory rather than adding a second one on the same subject.
- **Proposal doc**: `.claude/proposals/<YYYY-MM-DD>-<slug>.md` in the current
  project. Create the directory if needed. One file per proposal:
  - **What** — the technique or gotcha, written so it stands on its own.
  - **Why shared** — where it came up, and why it isn't specific to this project.
  - **Target** — which shared skill or agent it affects, and whether it's an edit or
    something new.
  - **Suggested text** — draft wording, ready to paste after review.
  - **Source** — this project and the date, so the context is recoverable.

## Step 5. Report

Short summary:

- what changed in the project,
- what went to memory,
- **any proposals written** — filename plus one line on what it asks for, so the user
  knows something is waiting for review,
- what was harvested but deliberately dropped, one line each.

The user needs to be able to disagree with your filtering.

Do not commit or push unless the user asks.
