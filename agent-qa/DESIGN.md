# agent-qa — design

**Status:** draft, 2026-11-22. Prototype pieces exist: `briefs/planner.md`, `briefs/executor.md`,
`schemas/`, `tools/screen.py`, `tools/type.py`. No runner yet. Trial 1 (TaigaMobileNova) ran
2026-11-23 and Trial 2 (wallosmobile) ran 2026-11-24: see [Trial 1](#trial-1-2026-11-23) and
[Trial 2](#trial-2-2026-11-24); their lessons override the sections above where they disagree.

Local, on-device QA runs driven by headless Claude Code sessions (`claude -p`). The generic
runner lives here in agentic-grappim. Each app repo supplies its own prerequisites: build, test
backend, credentials, scenarios and checks. Consumers so far: TaigaMobileNova, wallosmobile.

## Goals and non-goals

**Goals**
- Check a change on a real emulator against a real test backend without me driving it.
- Pass/fail decided by **deterministic checks** (the backend's API, the app's DB, logcat), not by
  the agent's own opinion. The agent drives the UI; code gives the verdict.
- Each run produces a readable report with numbered screenshots, plus a machine-readable verdict.
- Add exploration with personas later on the same runner.

**Non-goals**
- Replacing unit, integration or Compose UI tests. Known, repeatable checks belong in code. Agent
  runs cover what code doesn't reach yet, and may produce new code tests (see *Promotion*).
- CI or GitHub Actions. Local only for now.
- Parallel multi-device runs. One emulator, runs in sequence.
- A big hand-written scenario library. Scenarios are generated from the change (`verify`) or kept
  as a small smoke set (5–10).

## Modes

| Mode | Input | What runs | Verdict |
|---|---|---|---|
| `verify` | a git range (default `master...HEAD`) | planner session writes a checklist from the diff → you approve it → executor session runs it | checks + step results |
| `smoke` | `<project>/agent-qa/scenarios/smoke/*.yaml` | one executor session per scenario | checks + step results |
| `run` | one scenario file | one executor session | checks + step results |
| `explore` *(later)* | persona ids | executor with the exploration brief | findings only, no pass/fail |
| `reproduce` *(later)* | issue number or steps as text | executor with the reproduce brief | reproduced: yes / no / unclear |

`verify` and `smoke` share one scenario format. A good generated checklist can be saved into
`scenarios/smoke/` unchanged.

## Architecture

```
run.sh <project> <mode> [args]
 │
 ├─ load   <project>/agent-qa/config.sh  (+ config.local.sh, gitignored)
 ├─ hooks  preflight   backend reachable? emulator up? → fail fast with a clear message
 │         build       only when the APK is older than HEAD, or with --build
 │         install     adb install -r
 │         seed        idempotent test data (e.g. the "agent-qa" project in Taiga)
 │
 ├─ [verify only] PLANNER   claude -p, cwd = project, read-only tools, --json-schema
 │                          → runs/<id>/checklist.yaml → printed, wait for y/N (skip with --yes)
 │
 ├─ for each scenario:
 │     hook reset                pm clear, or snapshot load (later)
 │     EXECUTOR                  claude -p, cwd = runs/<id>/, device tools only, --json-schema
 │                               → screenshots NN.png, report.md, steps.json
 │     CHECKS                    python, project's checks.py, no model involved
 │                               → checks.json
 │
 └─ merge → runs/<id>/verdict.json + SUMMARY.md
```

### Two sessions, two sets of permissions

- **Planner.** Reads code, never touches the device. Tools: `Read`, `Grep`, `Glob`,
  `Bash(git diff:*)`, `Bash(git log:*)`. It runs in the project directory, so it gets the project's
  CLAUDE.md and docs. Output is forced through `--json-schema` into the scenario format.
  The checklist is a file you can read and edit before anything runs.
- **Executor.** Touches the device, never the code. Tools: `Bash(adb:*)`, the screen and type tools
  below, and `Read`/`Write` (it runs with cwd = the run directory). It runs in the run directory,
  so no project CLAUDE.md is picked up. Its context is passed explicitly with
  `--append-system-prompt`: the executor brief, the project's `docs/EMULATOR_TESTING.md`, and the
  scenario. `--permission-mode dontAsk` makes anything outside the allowlist get denied, not wait
  for a prompt. `--max-budget-usd` caps each session.

Keeping them separate means the executor can't "fix" the app to make a step pass, and the planner
can't reason from what it saw on screen instead of from the code.

### The verdict

For each step the executor reports `passed | failed | blocked` with screenshot numbers and a short
note (`steps.json`, schema-enforced). Then the runner runs the scenario's `checks` itself.

| Executor says | Checks say | Result |
|---|---|---|
| passed | pass | **PASS** |
| failed / blocked | fail | **FAIL** (agrees: real bug or broken flow) |
| passed | fail | **MISMATCH**: the agent misread the screen, or the UI claims success the backend never got. Investigate both ways |
| failed / blocked | pass | **MISMATCH**: the data is right but the UI hid it or the agent got lost |
| any | no checks | **UNVERIFIED** (UI-only step: shown, but never counted as a pass) |

Anything else the executor noticed along the way (cut text, slow screens, a crash in logcat) goes in
`findings`, separate from pass/fail.

## Scenario format

YAML (PyYAML 6 is already on this machine). The same format is used for hand-written smoke
scenarios and planner output.

```yaml
id: create-story
title: Create a user story from the backlog
why: smoke — the most common write path      # verify: which diff hunk this covers
preconditions:
  - logged in as {{user}} to {{server}}
  - project "{{qa_project}}" exists          # created by the seed hook
steps:
  - do: Open project "{{qa_project}}", go to Backlog, create a user story titled "{{tag}} story"
    expect: The story appears in the backlog list with status New
  - do: Open the story, change its status to In progress, go back
    expect: The list shows the story as In progress
checks:                                        # run by the runner after the executor finishes
  - story_exists: {subject: "{{tag}} story", status: "In progress"}
cleanup:
  - delete_stories: {subject_prefix: "{{tag}}"}
```

- **`{{tag}}`** is unique per run (`aq-20261122-1530`). Everything the agent creates carries it, so
  checks find exactly this run's data and reruns never collide. Then most scenarios don't need a
  full backend reset.
- **`checks` are named functions** in the project's `checks.py`, not a mini-language. They are
  plain Python, deterministic, and testable on their own. Each one returns `(ok, detail)`.
- The planner may only use check names that exist. The runner gives it the list of functions and
  their docstrings.

## What each app repo provides

```
<project>/agent-qa/
  config.sh            committed: package id, activity, APK path, build command, emulator → backend URL
  config.local.sh      gitignored: AVD name, test user and password, host backend URL
  hooks.sh             preflight / build / install / seed / reset — functions, each may be empty
  checks.py            named deterministic checks + cleanups
  scenarios/smoke/     the small fixed set
  runs/                gitignored output
```

Plus the existing `docs/EMULATOR_TESTING.md`, which the executor reads unchanged.

`config.local.sh` follows the README's machine-local rule (machine-specific values stay out of
git). It needs its own `.gitignore` line (TaigaMobileNova lists `docs/machine.local.md` literally,
with no glob).

### TaigaMobileNova specifically

| Piece | Value / source |
|---|---|
| Build | `./gradlew :androidApp:assembleFdroidDebug` → `androidApp/build/outputs/apk/fdroid/debug/app-fdroid-debug.apk` |
| Package / activity | `com.grappim.taigamobile.fdroid.debug` / `com.grappim.taigamobile.MainActivity` |
| Backend | local Docker Taiga, host `http://localhost:9000`, emulator `http://10.0.2.2:9000` |
| Preflight | `curl -sf localhost:9000/api/v1/` ; `adb get-state` ; correct AVD booted |
| Test user | `user1` (not `admin`, so permission bugs show up), from `config.local.sh` |
| Seed | create project `agent-qa` through the API if it's missing, with a few stories |
| Reset | `pm clear` (the logged-in-to-`:9100` trap in EMULATOR_TESTING.md goes away) |
| Checks | `checks.py` calls the Taiga REST API (`/api/v1/auth`, `/userstories`, …). It reads the same `TAIGA_INTEGRATION_URL/USERNAME/PASSWORD` env vars as the Kotlin integration tests, so one set of credentials covers both |

### wallosmobile specifically

| Piece | Value / source |
|---|---|
| Build / install | `./gradlew :androidApp:installGplayDebug -PgplayBuild`. Needs `androidApp/src/gplay/google-services.json` (machine-local) |
| Package / activity | `com.grappim.wallosmobile.debug` / `com.grappim.wallosmobile.MainActivity` |
| Backend | local Docker Wallos, host `http://localhost:8282`, emulator `http://10.0.2.2:8282`. Preflight `curl -sf localhost:8282` |
| Test user | from the repo's `docs/local-info.txt` (LAN-only, committed on purpose) → `config.local.sh` |
| Seed | usually none: the real dataset has 36 subscriptions, Active and Inactive. Write checks can use the Wallos API (key from the db via `docker exec`) |
| Reset | at least `am force-stop`; scenarios otherwise leak UI state (an open filter sheet) |
| Checks | app storage: `run-as <pkg> cat files/datastore/wallos_storage.preferences_pb \| strings`, one DataStore file. The API key is stored encrypted (`v1:` prefix): check presence, not value |
| UI traps | login is one screen and the layout shifts after the first tap; "Log Out" in Settings has no confirm; default sort is Next payment, so Inactive rows (past dates) fill the first screen and the list *looks* filtered |

## Shared pieces built here

```
agentic-grappim/agent-qa/
  run.sh                 the orchestrator above
  lib/scenario.py        load YAML, fill {{vars}}, validate check names against checks.py
  lib/verdict.py         merge steps.json + checks.json → verdict.json, SUMMARY.md
  tools/screen.py        executor's eyes (see below)
  tools/type.py          text input with the shell-quoting gotcha handled
  briefs/executor.md     how to run a scenario: screenshot after every action, one retry policy, report format
  briefs/planner.md      how to turn a diff into a checklist: user-visible behaviour only, prefer checkable steps
  briefs/explore.md      (later) adapted from mobile-agent-testers' AGENT_BRIEF.md
  schemas/steps.json     --json-schema for the executor's result
  schemas/checklist.json --json-schema for the planner's output
  personas.json          (later) Android-only subset, their format
```

### `tools/screen.py` (one call = everything the executor needs to see)

Built from `skills/emulator-testing/ui.py` and mobile-agent-testers' `scripts/android/screen.py`:
1. Screenshot saved at half size as `NN.png` (cheaper to read), with the scale stated in the output.
2. Element list from `uiautomator dump`: kind (field/button/text), label, **centre in device
   pixels** ready for `adb shell input tap`.
3. Crashes since the last call (`logcat -b crash` + `AndroidRuntime:E`), then the buffer is cleared.
4. Accessibility check: clickable nodes with no label, touch targets under 48 dp.

## Taken from mobile-agent-testers

- The `screen.py` idea (screenshot + element centres + crashes + accessibility check in one call).
- Rules from their brief: screenshot after every action and look before the next; a blocked step is
  a finding, then change one thing at a time; leave a screen and come back before saying a setting
  does nothing; stop after N attempts on the same step.
- A strict `--allowedTools` allowlist for the device agent.
- A unique test identity per run (their `success+<persona>@…`, our `{{tag}}`).
- Later: their persona format and exploration brief, `reproduce` mode.

**Not taken:** CI runners, encrypting results (everything stays local), building every framework
(each project brings a build command), iOS (no use for it yet).

## Promotion

A scenario that keeps passing and covers something important should turn into a real test, which
is cheaper and deterministic end to end. For Taiga the targets are a `jvmTest` integration test
against the live instance (API-level behaviour) or a Compose UI test (UI-level). That is an
interactive task ("promote `create-story`"), not part of the runner. The runner only records how
often each scenario has passed in a row, so candidates stand out.

## Risks and open questions

- **Cost per run.** Unknown until task 2. Their numbers ($0.15–0.55 per 30-action session on Sonnet)
  are the rough expectation. `--max-budget-usd` caps it either way.
- **Executor reliability on this app.** EMULATOR_TESTING.md lists traps (Ctrl+A doesn't select all in
  Compose fields, a pre-filled stale server URL). The executor gets that file, but it may still stumble.
  MISMATCH results will show how often.
- **Subscription vs API key.** `--bare` (clean, reproducible context) only accepts `ANTHROPIC_API_KEY`.
  With a subscription we run without it, from the run directory, with `--setting-sources user` at most,
  so project settings don't leak in. To confirm in task 2 that hooks and plugins from user settings
  don't interfere.
- **Login on every scenario** costs turns. If it's slow, save an emulator snapshot after login
  (`adb emu avd snapshot save`) and load it in `reset`.
- **Checks in Python vs reusing the Kotlin API client.** Python is far quicker to run between
  sessions; Gradle startup per check is too slow. The duplication is small (a few REST calls).

## Trial 1 (2026-11-23)

Hand-run prototype on TaigaMobileNova `dev` (range `b4883b69..fe6a5d70`: #491, #493, #494, #496),
Pixel_10a (API 37), local Docker Taiga. The TaigaMobileNova session reviewed the planner's checklist
and the executor's screenshots against the code. Run files: the session scratchpad `aq-run1/`, not kept.

### What happened

| Stage | Result | Cost |
|---|---|---|
| Planner (Sonnet, read-only tools, `--json-schema`) | Schema-valid checklist: 3 scenarios + skipped list. Reviewer found 2 coverage misses and several wrong methods (below) | 27 s, 4 turns, $0.27 |
| Executor, try 1 | Every step `blocked`: its first command was `mkdir -p shots; python3 …`, the compound was denied, and it gave up | $0.13 |
| Executor, try 2 (brief fixed) | `markdown-single-newline`, 5/5 passed, confirmed on screenshots: it cleared the stale server URL, handled both API 37 dialogs, expanded "Show more" and the collapsed Comments on its own | 157 s, 44 turns, $0.49 |

The `--json-schema` result arrives in the `structured_output` field of `--output-format json`.

### Changes to the design

**Scenario format**
- Steps get a type: `do:` for the executor, `runner:` for what only the runner can do (seed or
  change backend data, `am kill` + relaunch, start or stop a logcat capture). The planner put
  "create an issue via REST" inside a `do:` step; the executor can't do that.
- Checks can attach to a step (`after_step: N`), not only to the scenario's end. A restore loop needs
  a capture and a check per iteration.
- "Repeat N times" is never one step. The runner loops (a `repeat:` on a block of steps) or the
  planner unrolls it.
- Scenarios can be parameterised (`for_each: [issues, epics, backlog]`). One fix in #496 has three
  call sites, and only one was ever tested on a device.

**Verdict sources.** REST alone is not enough. Checks may read:
- the backend REST API
- **logcat**: the runner owns `logcat -c` at a step boundary and parses Ktor `REQUEST` lines into
  (path, params, cancelled), matching params as a set, never the literal URL (param order isn't a
  contract). `screen.py` reads and clears only `-b crash`, so it never wipes this evidence.
- **app storage** through `run-as` (e.g. the filters DataStore file). For #496 this is the bug
  itself; the UI chip is secondary.

Rendering (line breaks, collapse, padding, colours, disabled buttons) stays with the executor and is
UNVERIFIED.

**Planner brief**
- Classify a commit by the files it changes, never by its subject. #493 "chore: close revisit
  entries" contained user-visible code (formatting toolbar disabled offline) and was skipped.
- Test the fix, not the feature. "Results filter correctly" already passed before #496. The check
  must target what was broken: request count, a wiped filter.
- Input method matters. `adb shell input text issue` arrives as one burst and can't tell a
  debounced search from an undebounced one. Per-character calls (about 100–200 ms apart) can.
- Expectations must be exact: "exactly 1 request, 0 cancelled", not "at most one cancelled".
- Size seed data so the behaviour shows. A 3-line description never reaches the 6-line collapse
  that #494 changes.
- Keep `skipped` and `scenarios` disjoint. No empty placeholder scenarios.
- Use the configured test user, not `admin`.

**Executor brief** (already applied)
- One command per Bash call, only in the allowed shapes. A denial is a wrong command shape to fix,
  not a reason to mark steps blocked.
- Expand collapsed content ("Show more", collapsed sections) before judging what's missing.

**Project side (TaigaMobileNova)**
- Seed data: issues, stories and epics in 2–3 statuses with a shared `{{tag}} searchable` token,
  a tagged issue, and Markdown stories (3 lines; 8 lines for collapse; a checklist to toggle). Today
  main-project has 2 issues and 1 epic, and no description with a newline.
- Saved filters can only be created through the UI (the DataStore is readable, not writable). So
  "save filter" is executor step 1, verified by the runner reading the file. Reset (`pm clear`)
  runs before a scenario, never between setup and the restore check.
- Login costs about 6 screens per run (stale pre-filled URL, nearby-devices dialog, unencrypted
  dialog). A post-login snapshot in `reset` is worth doing early.
- `EMULATOR_TESTING.md` names the old AVD; the executor needs the machine-local one, so the runner
  passes `config.local.sh` values in the prompt. `.gitignore` lists `docs/machine.local.md`
  literally, with no `*.local.md` glob, so `agent-qa/config.local.sh` needs its own line.
- Expected UI to list in `EMULATOR_TESTING.md`: descriptions collapse past 6 lines behind "Show
  more"; Custom fields, Attachments and Comments are collapsed by default on work-item details.
- System-image crash noise (a uwb HAL crashing in a loop) is not documented per project. Instead,
  `screen.py` shows only crash lines from the app's own pid when `AQ_PACKAGE` is set (done).
- A seeded @mention makes the mentioned user a watcher (server-side). Scenarios that check watchers
  must not share a story with the Markdown seed.

**Reset and snapshots**
- After loading a post-login snapshot, always `adb install -r` the APK under test, or the run tests
  whatever APK the snapshot froze.
- A snapshot also freezes app storage. Filter scenarios start by checking that the stored filter is
  empty rather than assuming it.
- Interim: `pm clear` only for scenarios that need a clean login state.

**Verdict.** Trial 1's 5/5 "passed" is, by the table above, **UNVERIFIED**: every step was UI-only
and no check ran. The reviewer agreed with the screenshots, but the summary must not say "all
passed" for that. The one deterministic check #494 allows is still missing: tap "task beta" and
assert through the API that the description now holds `- [x] task beta`, with alpha unchanged.

## Trial 2 (2026-11-24)

Hand-run on wallosmobile PR #155 (`dev..feat/persist-subscription-filters`): e477e5d moves the
Subscriptions filter and sort from `SavedStateHandle` to DataStore and clears them on disconnect;
d8af532 is a DI refactor. Pixel_10a (API 37), local Docker Wallos. The wallosmobile session played
the runner. Its scripts and scenarios are kept in [`trials/2-wallosmobile/`](trials/2-wallosmobile/)
(`run-exec.sh` is the starting point for task 2).

### What happened

| Stage | Result | Cost |
|---|---|---|
| Planner (Sonnet, read-only + git) | 3 scenarios, d8af532 correctly skipped. **Zero checks**, asked for seed data that wasn't needed, and an unobservable "no flash" expectation. Rewritten by hand into A/B/C | 13 s, 4 turns, $0.25 |
| Executor A: persists across force-stop + Dashboard round trip | Steps 2–4 passed. Step 1 "failed": a misread (below) | 102 s, 55 turns, $0.37 |
| Executor B: Clear filters keeps the sort | 3/3 passed | 59 s, 27 turns, $0.22 |
| Executor C: disconnect + re-login drops the criteria | 4/4 passed | 76 s, 42 turns, $0.26 |

Verdicts from app storage (`trials/2-wallosmobile/check.sh`, key `subscriptions_criteria`): absent
before A; `{"status":"INACTIVE","sort":"NAME"}` after A (restore works, opening the screen writes no
defaults); `{"sort":"NAME"}` after B; absent after C with the API key still present. All PASS.
A step 1 is a **MISMATCH** the check resolved: the default sort puts Inactive rows first, the
executor scrolled up instead of down and decided a filter was already saved. Total $1.10.

### Changes made

- **Planner brief:** checks read `backend_api`, `app_storage` (run-as) or `logcat` (Trial 1's lesson,
  now in the brief); a data change with no check is a planning mistake; seed only when existing data
  can't show the behaviour; no sub-second expectations; name *process death* vs *fresh launch* and
  pick the one the old code fails.
- **Executor brief:** a separate *fresh launch* shape (`am force-stop` + `am start`); scroll both
  ways before calling rows missing; use the literal tools path; bare screen numbers.
- **Schemas:** checklist checks gain `reads` (required) and optional `after_step`; `screens` must
  match `^[0-9]{2,3}$` (A returned `03`, B and C `shots/03.png`).

### For the runner (task 2)

- **Process death can't tell old code from new here.** `SavedStateHandle` survives `am kill`, so only
  `am force-stop` + start exercises the change. The allowlist needs both shapes:
  `Bash(adb shell am kill:*)` and `Bash(adb shell am force-stop <package>)`.
- **Checks after a step.** The runner can't step into a running session, so the trial split the work
  into three executor sessions at the check points. Either the runner splits scenarios at each
  `after_step`, or the executor gets one allowed "checkpoint" command that the runner answers.
- **Pin the device.** Emulators are shared between sessions: an earlier hand run drove the
  TaigaMobileNova session's Pixel_Tablet by accident. Set `ANDROID_SERIAL` and assert
  `adb emu avd name` before every executor session (as `run-exec.sh` does).
- **Snapshots bring back old APKs and old storage.** Booting from `default_boot` did both, which
  confirms Trial 1's rule: `install -r` the APK under test after any snapshot.
- **Reset between scenarios**, at least `am force-stop`: B ended with the filter sheet open and C
  started on it.
- **Allowlist both tool-path forms** (literal and `$AQ/...`) until every brief and prompt uses the
  literal path.

## Plan

Each task fits one clean session. Take the one marked NEXT, finish it, check it with its *Done when*,
then update this table.

| # | Task | Status |
|---|---|---|
| 1 | `tools/screen.py` + `tools/type.py` | ✅ prototype, used in trial 1 (2026-11-23). `type.py` is untested |
| 2 | Executor alone: `run.sh <project> run <scenario>`, no checks yet. Start from `trials/2-wallosmobile/run-exec.sh`; see Trial 2, *For the runner* | ⬅ NEXT |
| 3 | Taiga `checks.py` + seed, verdict merge, `after_step` checks. First check: the #494 checkbox toggle through the API (see Trial 1, *Verdict*). wallosmobile's `subscriptions_criteria` storage check is a ready second consumer | |
| 4 | Taiga smoke set (5–10 scenarios), `smoke` mode | |
| 5 | Planner + `verify` mode | |
| 6 | `explore` mode with personas | |
| 7 | `reproduce` mode | |

**1. Screen and type tools.** *Done when:* with Taiga open on the login screen,
`python3 tools/screen.py /tmp/x 01` saves the PNG and lists the server, login and password fields
with centres that hit when tapped; `type.py "a b'c"` types exactly that.

**2. Executor alone.** `run.sh`, `config.sh`/`config.local.sh`/`hooks.sh` for Taiga (preflight,
install, reset), `briefs/executor.md`, `schemas/steps.json`. *Done when:* `run.sh TaigaMobileNova run
scenarios/smoke/login.yaml` logs in as `user1` from a cleared app, writes screenshots, `report.md`
and a schema-valid `steps.json`, and the session's cost is recorded in the summary.

**3. Checks and verdict.** Taiga `checks.py` (`story_exists`, `delete_stories`), seed hook,
`create-story.yaml`, `lib/verdict.py`. *Done when:* a run gives PASS; deleting the story by hand
mid-run (or breaking the check) gives MISMATCH, not PASS.

**4. Smoke set.** Login, open project, create story, change status, comment, kanban move, search
(pick what matters). *Done when:* `run.sh TaigaMobileNova smoke` runs all of them and SUMMARY.md has
one row per scenario.

**5. Planner + verify.** *Done when:* on a branch with a known UI change, `run.sh TaigaMobileNova
verify` produces a checklist that covers that change, uses only existing check names, waits for
approval, then runs it.
