---
name: adversarial-review
description: Spawn a fresh subagent with no memory of this conversation to
  adversarially review the current change for correctness and simplicity, write up
  the assumptions and design decisions it infers and why, and publish the result as
  an Artifact. Use when the user says "adversarial review", "attack this change",
  "get a second opinion on this diff", "fresh eyes on this PR", or wants a blind
  review of their own (or Claude's) work before merging it.
disable-model-invocation: true
metadata:
  author: grappim
  keywords:
  - adversarial review
  - second opinion
  - fresh eyes
  - blind review
  - attack this diff
  - review my own PR
---

# adversarial-review

The session that wrote a change shares its own blind spots with anything that
inherited its context — including a reviewer that read the same conversation. The
fix is a reviewer that starts from nothing but the diff: a genuinely fresh subagent,
not a fork of this one.

## What NOT to do

- Do not review the diff yourself in this session.
- Do not use `subagent_type: "fork"`. A fork inherits this conversation's context,
  which is exactly the shared blind spot this skill exists to avoid.
- Do not pass the subagent any summary of what was discussed, why the change was
  made, or what you expect it to find. If the diff doesn't justify a conclusion on
  its own, the subagent shouldn't reach it either.

## Step 1. Determine the target

Resolve this yourself — the subagent has no conversation to ask, so it can't fill in
scope gaps.

Default to the working tree's pending diff (uncommitted changes, or the current
branch against its merge base with the default branch). If the user names a PR
number, branch, or commit range instead, use that.

Capture, to hand to the subagent verbatim:
- the repo path
- the exact diff target (commit range, branch comparison, or PR number/URL)
- any constraint the user just stated for *this* review (e.g. "only look at the auth
  changes", "skip the generated files") — the subagent won't otherwise know it exists

## Step 2. Launch the subagent

Use the `Agent` tool, a fresh (non-fork) agent type — `general-purpose` unless a more
specific project agent obviously fits the code better — and a fully self-contained
prompt. State the repo and diff target explicitly; don't reference "this change" as
if the agent had been following along.

Prompt shape:

```
You are reviewing a code change with no prior context — you have not seen any
conversation that led to it, and that is intentional. Review only what the diff
itself justifies; do not assume intent you can't verify from the code.

Repo: <path>. Target: <branch/PR/commit range>. <any user constraint, verbatim>

1. Get the diff (`git diff <range>` or `gh pr diff <n>`) and read every changed file
   in full, not just the hunks — surrounding code is what makes a change correct or
   not.
2. Adversarially review it for exactly two things:
   - Correctness: concrete failure scenarios — specific inputs, states, or races that
     produce a wrong result, a crash, or a security issue. Every finding needs a
     trigger, not a stylistic worry.
   - Simplicity: complexity beyond what the problem requires — duplication,
     unnecessary abstraction, dead branches, a primitive reimplemented that already
     existed.
   Skip formatting, naming taste, and anything with no concrete consequence.
3. Separately, write up the assumptions and design decisions this change embodies and
   why they were probably made — inferred from the diff itself (types, tests,
   commit messages, comments), not guessed. Be concrete: name the file/function and
   the decision, not a general theme. This section is the map a reviewer uses to
   decide what to double-check first.
4. Load the `artifact-design` skill, then publish one Artifact with two sections:
   findings (most severe first, each with file:line, the failure scenario, and a
   suggested fix or "no fix needed, flagging for awareness"), then the assumptions/
   design-decisions writeup.
5. Reply with: the artifact URL, plus a short pointer to what a reviewer should look
   at first and why.
```

Then wait. Do not speculate about what the subagent will find while it's running.

## Step 3. Hand back to the user

Relay the subagent's report as-is — the artifact link and its pointer to what to
check first. Don't re-summarize or soften findings; an unfiltered second opinion is
the entire value of this skill.

Applying fixes is a separate, explicit follow-up the user has to ask for — this
skill's job ends at the report.
