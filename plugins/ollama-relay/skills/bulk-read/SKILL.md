---
name: bulk-read
description: Delegate reading and summarizing multiple files to a local Ollama model
  instead of loading their raw contents into Claude's own context. Use when the user
  says "use ollama for this", "delegate this read", "summarize these files with the
  local model", or when a PreToolUse hook denial names this skill after blocking a
  large Read.
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/bin/bulk-read.sh *)
metadata:
  author: grappim
  keywords:
  - ollama
  - local model
  - delegation
  - token savings
  - bulk read
  - context management
  - qwen2.5-coder
  - offload
---

Runs a local Ollama model over the full contents of the given files and returns only
a terse bulleted answer to a specific question — the raw file text is sent to Ollama,
not to Claude, so it never enters this session's context. This is not a substitute for
reading a file directly when the next step is editing it.

```bash
${CLAUDE_PLUGIN_ROOT}/bin/bulk-read.sh --question "Which of these files define a Koin module?" --paths src/A.kt src/B.kt src/C.kt
```

## Step 0. Know why you're here

Either the user asked directly for this, or a `Read`/`Bash cat` call was just denied
by the `ollama-relay` hook. In the second case, the denial's `permissionDecisionReason`
already names the file path and the line threshold it exceeded — use that exact path,
don't re-derive it.

## Step 1. Gather the files and one narrow question

Collect the precise set of file paths and a single, well-scoped question. Vague or
multi-part questions measurably degrade the worker model's answers — ask one thing at
a time, and if you need several answers, run several targeted invocations rather than
one broad one.

## Step 2. Run the script

Invoke `bulk-read.sh` with `--question` and `--paths`. If it exits non-zero, its
stderr says exactly why — either the estimated prompt size exceeded the tested-safe
context ceiling (the script refuses to send rather than risk silent truncation), or
Ollama itself was unreachable. **In either case, read the file(s) directly instead.**
Never retry the same call blindly.

## Step 3. Use the result

Present the returned bullets, preserving whatever file/line attributions the model
included. Treat the answer as a description of surface-level content, not as a
verified fact you'd stake an edit on.

## What doesn't work

- **Never delegate a read that precedes an edit.** The worker model's summaries have
  no reliable line numbers. Always `Read` the exact target directly before editing it.
- **Never delegate reasoning, debugging, architectural judgment, or anything
  safety-critical.** The worker model describes what's visibly in a file — it is not
  a substitute for Claude's own analysis, and has been observed to miss subtler issues
  a direct read would catch.
- **Don't chain several `bulk-read` calls hoping to reconstruct understanding of
  complex, unfamiliar code.** That pattern is a sign a direct read is warranted.

## Shadow mode and enforcement

By default (`OLLAMA_RELAY_ENFORCE` unset) the hook only logs what it *would* block and
never actually redirects here — this skill may go entirely unused on a fresh install,
and that's correct, not a bug. Once `OLLAMA_RELAY_ENFORCE=1` is set, a `Read` or
`cat`/`head`/`tail`/`less`/`more` over `OLLAMA_RELAY_MIN_LINES` (default 350) lines
gets denied and pointed here. If Ollama is down or slow when that would otherwise
happen, the hook fails open instead — the original read proceeds normally, and this
skill is never invoked for that call. A denial naming this skill only ever happens
when Ollama was confirmed reachable at decision time.
