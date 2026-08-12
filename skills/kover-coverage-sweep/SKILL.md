---
name: kover-coverage-sweep
description: Run a coverage-sweep session against a Kover-instrumented Kotlin/KMP
  project — rank packages by missed branches or lines, read Kover's XML report
  accurately (denominator noise between runs, koverXmlReport-vs-koverVerify agreement),
  and recognize the recurring patterns that mean "this residual isn't worth a test"
  (generated equals/hashCode, Composable-blocked branches, an unreachable elvis arm, a
  no-op-backend lambda, a lifecycle callback). Use when the user asks to raise Kover
  coverage, close a coverage floor gap, run a coverage sweep, or interpret a Kover
  ranking/report.
metadata:
  author: grappim
  keywords:
  - kover
  - code coverage
  - coverage sweep
  - missed branches
  - missed lines
  - branch coverage
  - koverXmlReport
  - koverVerify
  - jacoco xml
disable-model-invocation: true
---

A methodical way to close a Kotlin/KMP project's Kover coverage gap: rank what's
actually worth testing, recognize the residuals that aren't, and avoid several report-
reading traps that produce false regressions or false "nothing changed" readings. This
is reference material for a sweep session, not a one-time setup — expect to come back to
it every session.

## Step 0. Read the report correctly before ranking anything

- **`koverXmlReport` and `:koverVerify` agree exactly — but only within a single
  invocation.** Both are typically handed the same filter object and the same
  artifacts by Kover's own internal wiring. Take readings from one invocation, not
  across separate runs — a claim that the two "apply excludes differently" is usually
  wrong and traceable to comparing non-contemporaneous runs instead.
- **What varies between separate runs is the denominator, not the filtering.** Kover's
  report task typically ends its file collection in something like `.existing()`, and
  root aggregation in a multi-module (especially KMP) build includes each module's
  *total* variant — which includes the Android library target where one exists. So a
  class is counted iff its compiler output happens to be on disk *right now*. An
  Android build, an iOS link, or a KSP/annotation-processor re-run since the last
  `clean` changes the class universe — total class counts in the high hundreds have
  been observed to vary across half a dozen different values on the same unchanged
  source, purely from build-state differences. **CI is the deterministic case** (fresh
  checkout, one target's compilations only) — that's why a CI-produced number is always
  trustworthy and a locally-reproduced one needs care. Locally: take before/after from
  runs with the same compilation state, or just re-run — the count isn't sticky within
  a session, and one re-run is cheaper than reasoning about a mismatched pair.
- **To read `:koverVerify`'s own percentages directly**, temporarily set both bound
  `minValue`s to 99 in the coverage-floor config and run it: it names each violated rule
  and prints the actual figure. There's usually no other way to get the number the gate
  is actually comparing against (a report task can round or use a different display
  precision). Revert the change afterward.
- **A moved percentage is not a moved numerator.** Kover's totals shift when the
  denominator changes, so compare `covered`/`total` counts between two reports before
  concluding coverage regressed — reading percentages alone can make a genuinely large
  batch of new tests look like a percentage-point *drop* if the denominator also grew
  in the same window.
- **The denominator-noise caveat is about report-level totals, not a single class.** An
  unexecuted class is reported with *fewer* branches/lines than it actually has (some
  branches only materialize in the report once something reaches them), so covering it
  for the first time can *grow* its own denominator between two same-class-count runs —
  e.g. a class moving from `BRANCH 0/4` to `14/14` and `LINE 29/49` to `55/55` in one
  session, purely from being exercised for the first time. Compare `covered` against the
  **after** denominator at class scope; don't read the growth itself as a bad
  measurement.
- **Sanity-check a report before quoting it**, in one command — this catches a rare but
  real intermittent bug where a single class survives an exclude pattern it should
  match:

  ```bash
  python3 -c "
  import xml.etree.ElementTree as ET
  n=[c.get('name') for p in ET.parse('build/reports/kover/report.xml').getroot().findall('package') for c in p.findall('class')]
  print(len(n), 'excluded-suffix leaks:', len([x for x in n if x.split('/')[-1].split('\$')[0].endswith(('Screen','Widget','Repository'))]))"
  ```

  (swap the suffix tuple for your own project's exclude list — or better, just run
  `kover-rank.py` below, which re-applies the real list and reports the kept-class
  count directly). **0 or 1 leaks is normal** and typically involves a hand-written
  DI-module-style class worth at most a line or two; a count in the dozens means the
  report isn't usable as-is — re-run.

## Step 1. Rank and diff

`references/kover-rank.py` re-applies your project's own Kover `excludes {}` rules to
whatever report you have, so a report carrying stray classes from an Android/iOS build
still gives a usable ranking:

```bash
./gradlew koverXmlReport
python3 kover-rank.py build/reports/kover/report.xml --excludes-file kover-excludes.txt
```

It reads exclude patterns from a small project-local text file (`kover-excludes.txt.example`
next to the script shows the format) rather than parsing them out of the Gradle build
script directly — a real `excludes {}` block commonly generates its suffix list through
a local helper function instead of a flat list of string literals, which defeats
straightforward parsing. Copy the example, fill it in from your own root
`build.gradle.kts` Kover block once, and keep it in sync by hand when that block
changes — same maintenance cost as the block itself, just co-located for the script to
read.

**When two reports still disagree, diff every counter rather than discarding the
measurement.** `references/kover-diff.py before.xml after.xml` loads
`{(name, type): (covered, total)}` for every `<package>` *and* `<class>` in both
reports and prints what actually moved, split by element type — because denominator
noise from a changed class universe only ever disturbs `<package>`-level totals (classes
leave/enter the key set rather than a value moving); a `<class>` row that moves is
always real. This is what rescues a badly straddled pair: two reports differing by
hundreds of classes overall can still show a target package's own denominators identical
in both with no class of that package missing from either — provably valid even though
the totals aren't comparable at all. Read the key-set difference and the per-target
denominators as two separate answers; only the class-level one gates your table.

**`koverXmlReport` always writes to the same output path.** Copy it aside immediately
after each run — forgetting once makes "before" and "after" the same file, and a diff
then shows nothing changed anywhere, which reads as a plausible result rather than a
mistake. Equally, don't write new test sources while a baseline run is in flight — it
compiles test sources partway through, so a file added at the wrong moment silently
lands in the "before" instead of the "after."

**On a clean tree at the same commit as the last session's final run, skip the baseline
run entirely** — `koverXmlReport` comes back `UP-TO-DATE` and the report already on disk
*is* the baseline. Copy it aside and run the leak/class-count check on it as usual. Do
this before writing any test, since the first test source you add is what makes the
task's compile state out of date.

## Step 2. Recognize residuals that aren't worth a test

Much of a branch/line denominator is unreachable from a plain unit test, in ways a
missed-count alone doesn't distinguish:

- **Generated code** — `equals`/`hashCode`/`copy$default` on data classes, and
  ORM/database-generated DAO implementations (Room and similar). A package can sit at
  a handful of covered branches out of well over a hundred with no hand-written
  conditional anywhere in it. **`@Serializable`-style generated serializers are *not*
  in this category, though** — they're reached by any test that serializes the type,
  wherever that test lives (a different module's test round-tripping the type through
  JSON can move this package's numbers with no test written directly against it). Don't
  quote a serializable-heavy package's missed branches as unreachable, but don't take it
  as a sweep target either — its reachable share moves as a side effect of testing its
  callers.
- **Composable-blocked branches** — hand-written branches inside `@Composable`
  functions/getters, which no plain JVM unit test can enter at all. Rank sweep work by
  missed branches in hand-written, *non-composable* code; a `@Composable`-heavy
  package's raw missed-branch count overstates what's actually closeable.
- **An excluded class is absent from the report entirely, not listed at 0 %** — so a
  class that is both excluded by your Kover config *and* genuinely dead code is
  invisible to every ranking; nothing in a missed-branch sweep can surface it. When a
  sweep closes out a package, `ls` its source directory against the class names
  actually present in the report before calling the package done — the difference is
  the excluded set, worth a look for dead code hiding in it.
- **A platform-variant facade class is dead weight if CI only runs one target's
  tests.** A KMP project whose root coverage aggregation compiles in an Android (or
  iOS) target's classes, while CI runs only JVM tests, leaves every such facade at a
  permanent 0 % — best fixed by excluding the pattern from the report entirely (e.g. a
  `*_androidKt`-shaped suffix) rather than chasing it in a ranking. Before scoping any
  `expect`/`actual` package, diff the platform actuals: if the JVM actual is
  byte-for-byte equivalent logic to the unreachable platform one, the logic is already
  tested once, just counted twice.
- **An unreachable elvis arm on a `?.`-chain.** `x?.someCall() ?: default` is typically
  3/4 covered forever when the chain's last link cannot itself return null — e.g.
  `?.toString()` on a non-null receiver never returns null, so the elvis's null arm is
  dead on that code path however the receiver is null-checked upstream. Recognise the
  *shape* (a `?.`-chain whose last link is non-null-returning, feeding an elvis), not
  just "there's an elvis" — **its report signature is `mb=1 cb=3` on that line** (see
  Step 3), and a getter written as `get() = x as? T ?: error(...)` is a reliable
  producer of it: `error()` returns `Nothing`, so the property is typed non-null and
  every safe-call read of it downstream is one branch short forever. When several call
  sites show the same one-short shape at once, look for a shared non-null-typed callee
  rather than testing each site individually.
- **A no-op-backend lambda is a permanent LINE hole, not a branch.** Any call whose
  actual/platform implementation on the build being tested is a no-op (a logging call
  whose test-target backend never invokes its `message: () -> String` lambda is the
  canonical case) leaves a synthetic method Kover reports as one missed line and zero
  branches — recognisable as **a 1-line hole in an otherwise 100 % method.** Stop there
  rather than hunting for a test that would reach it; it's unreachable on this platform
  by construction. The same applies to a state class's callback parameter default that
  the consuming code always overrides (`onSave: (T) -> Unit = {}`).
- **A lifecycle callback unreachable from a unit test.** Framework lifecycle methods
  (e.g. `ViewModel.onCleared()`) are commonly `protected`/internal to the framework, so
  nothing in a plain unit test can trigger them — recognise the override and skip it,
  same family as the no-op-lambda holes, just larger.

## Step 3. Reading the per-line breakdown to size a session

Kover's XML carries `<counter>` elements on `<package>`, `<class>`, **and** `<method>`,
and (per source line) `mb`/`cb` (missed/covered branches) on `<sourcefile>`'s `<line>`
children. Go down a level whenever the one above is too coarse:

- **Per-method** answers "which function still has missed branches" without reading the
  source.
- **Per-line** is needed once a whole coroutine body collapses into one
  `invokeSuspend` method in the per-method view — the per-line view names the exact
  source line (`mb=1 cb=3`) instead.
- **Run this at scoping time, before writing any test**, not only to explain a
  leftover afterward. Dumping every `mb>0` line for a target class turns a large,
  vague-looking class into a checklist, and prices the session honestly — it's often
  what reveals that half the residual is branch-free (a LINE problem, see Step 4) and
  needs splitting off from the branch work.

**Read the `mb`/`cb` split, not just `mb>0`** — it says which lines are worth a test
before you write one:

| Signature | Meaning | What it costs |
|---|---|---|
| `mb=2 cb=2` on a `?.`-chain | one input path (e.g. the null case) never tried | +1 test |
| `mb=1 cb=3` on a `?.`-chain feeding an elvis | the dead arm from Step 2 | nothing — don't test it |
| `mb=2 cb=0` | line never executed at all | 2 tests (both branches untried), not 1 |
| `mb=4 cb=2` on a `find { … } ?: return null`-shaped line | the lambda body was reached by *another* method's test walking the same collection; only this method's own elvis is untested | 1 happy-path test closes all of it — don't price it as 4 |
| `mb=0 mi>0` (LINE-only) block, often a mapper's collection lambda | usually a hard-coded `null`/empty default in a test factory starving the lambda of input, not a missing test shape | 1 test with a non-empty/non-null input |

**The general rule behind the table: price a line by how many distinct *values* its
input can take, not by its raw `mb` count.** A boolean-ish chain like
`x?.isNotEmpty() == true` on a three-valued `String?` is commonly `mb=5 cb=1` (safe
call, boolean test, boxed comparison) — but it's still just three tests (null / empty /
non-empty) that close all five branches, because one input drives every branch on that
line together. Read a block of related lines together for the same reason: a
never-called method can show a misleadingly split-looking set of `mb`/`cb`/`mi>0`
signatures across its guard clauses and body that are really priced by "how many tests
does this whole method need," not by summing each line's own count.

**Filter a scoping dump on `ci=0` (never executed), not `mi>0` (has any missed
instructions).** A line can carry both `mi>0` and `ci>0` at once — a partially-covered
expression that some existing test already reaches part of. Filtering on `mi>0` puts
already-exercised lines at the top of an "untested" list; only `ci=0` lines are the
ones genuinely never executed.

## Step 4. Cheap, high-yield row shapes

- **The "sleeper" signature: a low-missed-branch row that's *also* low on LINE.** A
  `BRANCH 0/n` **and** `LINE 0/m` pairing on a coroutine-body class (a `$1`/`$2`
  synthetic) means the whole method body never ran — the branch count only prices the
  `Result`-style `onSuccess`/`onFailure` arms, while the real prize is the untested body
  around them. Such a row can rank far below bigger-looking rows by raw missed-branch
  count and still be the best session available, closing an entire package to 100 % on
  every counter in one pass. **Rank by the LINE gap, not by `missedB`, when this shape
  shows up** — a package's twin/sibling module (same constructor shape, same delegate
  pattern) having already been tested is a strong hint the current row is the same
  sleeper shape; its existing test usually transfers almost verbatim.
- **A pure-mapper or pure-top-level-extension-function file is the cheapest row type
  there is.** No `logcat`/no-op call, no coroutine, no collaborator that can throw — a
  handful of tests can take such a file from 0 to 100 % on every counter (branch, line,
  method, instruction) in well under an hour. Recognise it by a whole package sitting
  at `LINE 0/n` with a `…Kt` top-level-function class name: no class to construct, no
  fake to wire, the only work is enumerating each expression's input values.
- **A `*Mapper`-shaped row whose LINE is *also* short is the same cheap-and-high-yield
  kind, for a specific reason: a shared test-data factory's hard-coded `null`/empty
  default is starving one collection-mapping lambda of input, not signalling a missing
  test *shape*.** Check the factory's defaults before scoping the package — often one
  `.copy(field = listOf(…))`-style test closes the whole LINE gap at once. The inverse
  also holds: a `*Mapper` already at full LINE with residual *branches* is the Step 2
  unreachable-elvis-arm kind, not a missing-input kind.
