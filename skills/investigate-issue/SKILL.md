---
name: investigate-issue
description: Investigate a reported bug or issue properly before writing any fix —
  establish the root cause from evidence, write an investigation doc under
  `docs/issues/`, weigh the options with real tradeoffs, and only then break an
  approved fix into independently testable parts. Use when the user shares a GitHub
  issue URL or number, says "check this issue", "look into this bug", "triage this",
  or otherwise reports a defect to diagnose.
metadata:
  author: grappim
  keywords:
  - issue
  - github issue
  - bug
  - bug report
  - triage
  - investigate
  - root cause
  - defect
  - reproduce
---

The failure mode this exists to prevent: read a bug report, spot a plausible-looking
line, ship a fix in the first response. Plausible is not verified, and a fix that
lands before the cause is understood is a guess wearing a diff.

So: investigation first, the **doc is the deliverable**, and the fix is a separate
decision the user makes — not a continuation of the same breath.

This skill is installed for the user account, so it runs in **every** project. Write
to the project you are currently in.

## Step 1. Establish what was actually reported

Fetch the issue verbatim, including comments. Don't work from the user's paraphrase.

```bash
gh api repos/<owner>/<repo>/issues/<n> --jq '{number,title,state,user:.user.login,labels:[.labels[].name],body}'
gh api repos/<owner>/<repo>/issues/<n>/comments --jq '.[] | {user:.user.login,created_at,body}'
```

Use `gh api`, not `gh issue view` — the latter fails on repos with Projects-classic
enabled (`GraphQL: Projects (classic) is being deprecated ... repository.issue.projectCards`).

Then split the report into three separate things, and keep them separate:

| | How to treat it |
|---|---|
| **Symptom** — what the user observed | Fact. This is what a fix must actually resolve. |
| **Environment** — version, platform, self-hosted vs cloud | Fact, and often the discriminator. |
| **Reporter's diagnosis** — their theory of the cause | **Hypothesis to test.** Never a premise. |

Reporters are frequently right about the symptom and wrong about the cause. A report
that names a cause is the most dangerous kind, because it invites you to skip Step 2.

Also write down what the report *doesn't* say — missing repro steps, version, or
platform. Those gaps become open questions, not silent assumptions.

## Step 2. Investigate from evidence

Trace the full path from the entry point the user touched to the boundary where
behaviour is observable (network call, database write, rendered UI). Do not stop at
the first suspicious line — confirm nothing else on that path also affects the
outcome. Two contributing causes is a common and easily-missed shape.

Rules:

- **Every claim carries evidence** — a `file:line`, a command's output, or a quote
  from a spec. If something is inference rather than verified, label it as inference.
- **Read the other side of the boundary.** If the bug involves a server, API, or
  library, read that source or its spec. Do not reason from memory about what a
  third party does.
- **Try to falsify your own hypothesis.** Ask what would have to be true for it to be
  wrong, then go check that specific thing.
- **Prefer reproducing.** A test that fails for the reported reason is the strongest
  evidence available, and it becomes the regression test later. If you cannot
  reproduce it, say so explicitly rather than treating the trace as confirmation.
- **List what you could not resolve.** An open question in the doc is a perfectly good
  outcome. A quietly-papered-over gap is not.

## Step 3. Write the doc

Path: `docs/issues/<issue-number>-<slug>.md`, or `<YYYY-MM-DD>-<slug>.md` when there's
no issue number. Create the directory if needed.

This is versioned project documentation, not agent scratch — it gets committed and
reviewed alongside the fix. Keep it readable by someone who was never in the session.

```markdown
# <number> — <title>

**Status:** Investigating | Awaiting decision | Approved | In progress | Done | Won't fix
**Link:** <url>   **Updated:** <YYYY-MM-DD>

## Report
What was reported, in the reporter's words. Environment. What the report omits.

## Findings
What is now verified, each with its evidence (`file:line`, output, spec quote).
Mark anything that is still inference.

## Root cause
One precise paragraph. Exact location. If it is not yet known, say that instead of
reaching for the nearest plausible line.

## Impact
Who hits this, how often, how badly. Is there a workaround?

## Open questions
What is unresolved, and whether it blocks a decision.

## Options
(Step 4)

## Decision
(Step 5)
```

Write the doc **even when the fix looks like one line.** The doc is what makes a
one-line change reviewable by someone who wasn't in the session — and one-line
changes to things like credential handling, auth, or persistence are exactly where
an unreviewed guess does the most damage.

Default to writing it. Skip only when the user explicitly says to just fix it, or the
change is a literal typo with no behavioural question attached.

## Step 4. Options and tradeoffs

Where more than one route exists, give at least two — and include "do nothing" or
"won't fix" whenever it is genuinely on the table.

For each option: what it changes, pros, cons, risk, and blast radius (what else could
this break?).

- **Cons must be real.** If you cannot name a genuine drawback of an option, you have
  not understood it well enough to recommend it.
- **Always recommend one**, with the reason. A menu without a recommendation pushes
  your job onto the user.

Not every issue ends in code. **Won't fix**, **needs info from the reporter**,
**upstream bug**, **already fixed**, and **working as intended** are all legitimate
outcomes — write them up with the same rigour, since the reasoning is the value.

## Step 5. Stop. Get the decision.

Present the findings and the recommendation, then **stop**. Do not start implementing.

This checkpoint is the reason the skill exists. The user may disagree with the root
cause, know something about the system you don't, or prefer a different tradeoff —
all of which are cheap to act on now and expensive once code is written.

Record the decision and who made it in the doc, then update **Status**.

## Step 6. Break the work into testable parts

Only after approval.

Each part must be: one reviewable change, independently verifiable, and leave the
repo in a working state (build and tests green) on its own.

For every part, name the verification — **which** test file, **what** it asserts, and
whether it fails before the change. A part with no verification story is not ready to
implement. If something genuinely cannot be tested automatically, state how it will
be checked by hand and why automation isn't possible.

**If the defect is intermittent, one green run is not evidence.** Races, ordering
dependencies and timing bugs pass by luck all the time — that is what makes them
races. Establish a before-state *rate* ("2 of 3 runs failed, each blaming a different
test"), then re-run the fixed state the same number of times. State the count in the
doc, because "it passes now" is exactly what someone said before shipping the flake.

Order the parts so the failing regression test comes first, then the fix that turns
it green, then any cleanup.

One part is a perfectly good plan — don't manufacture phases to look thorough. For
three or more, track them with the task list.

## Step 7. Implement

- Follow the agreed plan. If reality contradicts it, **stop and update the doc**
  rather than improvising past the decision the user made.
- Keep scope tight: every changed line traces to this issue. Adjacent problems you
  notice get **noted in the doc**, not fixed.
- When done, set **Status** and add a short "What landed" section — the change, the
  test that covers it, anything deliberately left out.
- Do not close the issue, commit, or push unless the user asks.