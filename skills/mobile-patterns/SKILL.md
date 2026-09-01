---
name: mobile-patterns
description: A growing reference of confirmed, project-agnostic Kotlin/KMP mobile architecture facts and platform behaviors — not a procedure to run, a knowledge base to check before answering a coroutines/ViewModel/lifecycle/navigation/module-boundary/CI question in any Android or Kotlin Multiplatform project, and to add to whenever an investigation in one project confirms something that generalizes. Check it when reasoning about coroutine exception handling, ViewModel state restoration, deep-link/back-stack design, feature-module coupling, or similar cross-cutting mobile-architecture questions.
disable-model-invocation: true
---

# mobile-patterns

Confirmed facts and reusable patterns that came out of investigating one project but hold
generally for Kotlin/KMP mobile apps. Each entry names the project/date it was confirmed in so a
claim can be traced back to its evidence rather than taken on faith.

Read the relevant entry before answering a question in its area. Add a new entry whenever a
project's own investigation turns up something project-agnostic — this is what `finalize` routes
that kind of finding to, per its own Step 3 routing table.

## Architecture

### Cross-feature module coupling is sometimes the deliberate design, not unenforced tech debt

Confirmed TaigaMobileNova, 2026-09-01, while assessing whether to port a `feature-*` module
isolation rule (Gradle-level: build fails if one feature module depends on another) from
HedvigInsurance. Hedvig's rule fits *its* architecture — `feature-*` modules there are independent
vertical slices, reachable cross-feature only through a small `feature-x-navigation` module holding
just the nav keys. Porting the same rule to TaigaMobileNova would have been wrong: its `feature/*`
modules are decomposed by *layer* (ui/domain/data/mapper/dto) within a business domain, and those
domains reference each other's models directly by design (an epic has user stories, a task has an
assignee from `users`, etc.) — grepping every `feature/*/*/build.gradle.kts` found pervasive,
intentional `projects.feature.*` coupling, not drift from an unstated rule.

**Takeaway:** before recommending a module-isolation rule seen in another codebase, check which
shape of "feature module" the target project actually has — an independent-vertical-slice
architecture and a layered-domain-decomposition architecture look superficially similar (both have
a `feature/` directory) but call for opposite answers to "should features depend on each other."

## Coroutines

### An unhandled root-coroutine exception (no `CoroutineExceptionHandler`) behaves differently per platform

Confirmed TaigaMobileNova, 2026-08-29, investigating whether `provideApplicationScope`-style
top-level scopes need a `CoroutineExceptionHandler`.

- **JVM/Desktop**: falls through to the thread's default uncaught-exception handler, which prints
  the stack trace to `stderr` and lets that one pool thread die; the pool replaces it. Truly silent
  in production — nobody is watching stderr on a shipped desktop app.
- **Android**: the OS installs a process-wide default `Thread.UncaughtExceptionHandler` at startup
  that logs a "FATAL EXCEPTION" and kills the process. If a crash-reporting SDK (Crashlytics,
  Bugsnag, etc.) is present, it chains onto that same handler — reports the exception as a
  **fatal** crash, then still kills the process. So on Android this is generally *not* silent: it's
  either a reported crash (SDK present) or a visible, unreported "app has stopped" (SDK absent),
  contrary to how some articles frame this as universally invisible.
- **iOS/Kotlin-Native**: an uncaught exception in a worker/coroutine similarly terminates the
  process by default.
- **`SupervisorJob` has no bearing on any of this** — it only stops sibling coroutines/the parent
  from being cancelled by a child's failure. It says nothing about logging or crashing; that's a
  separate axis (`CoroutineExceptionHandler`) entirely.

**Takeaway:** "add a `CoroutineExceptionHandler` to every top-level/application-scope coroutine
scope" is universally good advice, but *why* it matters differs by platform — on JVM it turns an
invisible failure into a visible, logged one; on Android/iOS it turns an app crash into a
contained, logged failure instead (or, with a crash SDK, into a *correctly attributed* one instead
of an ANR/generic native crash).

### `viewModelScope` (androidx.lifecycle, common to Android/iOS/JVM) is backed by a `SupervisorJob`

Confirmed by reading `androidx.lifecycle`'s own `commonMain` source
(`androidx/lifecycle/viewmodel/internal/CloseableCoroutineScope.kt`, 2.11.0): `CloseableCoroutineScope(coroutineContext
= dispatcher + SupervisorJob())`. Two independent `viewModelScope.launch {}` calls (e.g. two
unrelated loads fired from `init`) cannot cancel each other on failure — each fails
independently. This is a real, general fact about the platform, not an assumption to re-derive
per project when reasoning about whether concurrent `init`-launched coroutines are safe.

**Related correctness check, not platform-specific but easy to skip:** two concurrent coroutines
writing to the same `StateFlow` via `.update {}` are only safe from each other if they write
*disjoint* fields — `.update {}` is atomic per call, but says nothing about ordering between two
independent calls. If both write the same field, the last one to finish wins regardless of which
was launched first; that's a real race if the two writes aren't meant to agree. Confirmed
TaigaMobileNova, 2026-08-30, reasoning about whether concurrent independent `init` loads are a
production risk (they weren't, in that case — disjoint fields).

## ViewModel / Compose state restoration

### `SavedStateHandle`-backed restoration needs an explicit "already restored" gate, or `init` re-fetches over it

Candidate pattern flagged TaigaMobileNova, 2026-08-29 (not yet adopted there as of that date —
check the project's own docs for current status before assuming it's live). The problem: a
ViewModel that both (a) restores prior state from `SavedStateHandle`/a serialized blob and (b)
unconditionally kicks off a network/repo load from `init` will have that `init` load overwrite the
just-restored state the moment it resolves — restoration "worked" for a frame and then got
stomped.

The fix shape: wrap the saved-state read in a state holder that exposes whether it actually
restored something this instantiation (`isStateRestored: Boolean` or equivalent), and gate the
`init`-time load on it — skip the fetch when state was restored, run it normally on a fresh
instantiation. This is a general MVVM/Compose pattern, not specific to any one project's
architecture.

Two caveats that surfaced while assessing this for a KMP project, and are probably relevant
anywhere this pattern gets proposed:
- The pattern as usually described online assumes single-platform Android + Hilt
  (`@HiltViewModel constructor(savedStateHandle: SavedStateHandle)`). Check case by case whether
  `SavedStateHandle` (or its KMP equivalent) is actually usable the same way before presenting it
  as a drop-in recipe in a KMP or non-Hilt-DI project.
- `@Parcelize` is the natural serialization choice for the restored state class on Android, but
  doesn't play well with `kotlinx-collections-immutable` types (`ImmutableList`, etc.) out of the
  box. For a project already on kotlinx-serialization, `@Serializable` + a JSON blob in the saved
  state is the more portable alternative.

## Navigation (Navigation 3 / synthetic back stacks)

Three related patterns from reading HedvigInsurance's real Navigation 3 implementation
(`agentic-grappim/investigations/reference-app-scouting.md`, 2026-09-01, since deleted once its
findings landed here and in the two projects' own docs). None was implemented anywhere yet as of
that date — TaigaMobileNova's and WallosMobile's `Navigator`s both have only a single `goBack()`
pop primitive and no deep-link handling, so there was nothing to verify by running code. Recorded
here so a session adding deep links to a hand-rolled Nav3-style backstack doesn't have to
re-discover the shape from scratch.

### Marker interfaces on a nav key for cross-cutting shell concerns

Instead of a shell-level `when (key) { ... }` or a single boolean field bolted onto every
destination key, give each cross-cutting concern (is this a tab root? does this key need a
synthetic parent stack when reached via deep link? should a push notification be suppressed while
it's shown?) its own small marker interface that a key opts into; the shell does `key is
ThatInterface` checks without importing anything from the owning feature module. A key can
implement several. **Only pays off once the shell needs to ask "does this screen do X" for more
than one X** — a single existing need (e.g. "is this a top-level tab root") is better served by a
plain `Set<NavKey>`/boolean field; reaching for marker interfaces before a second concern exists is
premature abstraction.

### Reserve a deep-link-aware "up" for the top-app-bar back arrow only

If a back-stack system has (or grows) two different pop operations — a plain temporal pop, and a
"smarter" one that can rebuild a synthetic parent stack for a screen reached via deep link — the
smarter one must be wired *only* to the top app bar's system-back-affordance arrow. Every
"done"/"close"/"continue" button, success screen, or programmatic pop after an in-app action should
use the plain pop instead. Mixing them makes a button's behavior depend on how the screen was
*reached*, which is surprising and can diverge from predictive/system back. This is a naming/usage
discipline, not a mechanism — the footgun only exists once a codebase has two pop operations with
different semantics, so it's irrelevant until deep links (or another synthetic-stack feature) are
added.

### Deep-link matcher aggregation + a single pending-deep-link slot for the logged-out case

Three separable ideas for wiring up deep links in a modular app: (1) each feature contributes its
own URL-matching patterns into one app-wide aggregated matcher, instead of a central registry
hardcoding every feature's patterns; (2) a deep link arriving before auth state has resolved is
held as **at most one** pending target and landed after login, rather than dropped or raced against
the login flow; (3) a synthetic-parent-stack marker (see above) on the target key supplies a
sensible "up" destination so a deep-linked screen doesn't strand the user with nowhere logical to
navigate up into. The logged-out-queueing behavior (2) is the part most likely to be gotten wrong
on a first attempt — a naive implementation either drops the link or crashes navigating before the
graph is ready.

## CI / Android Gradle Plugin

### AndroidX Macrobenchmark's structured JSON output beats a hand-rolled Perfetto capture for CI regression tracking

Flagged TaigaMobileNova, 2026-08-29, not yet proven end-to-end as of that date (check the
project's own docs before citing this as confirmed — it was still an open prototype question).
The idea: a `MacrobenchmarkRule` with `StartupTimingMetric`/`FrameTimingMetric` captures a
Perfetto trace under the hood automatically and emits a structured `*-benchmarkData.json` result
per run — a much better artifact to diff run-over-run for a CI regression signal than a by-hand
`adb shell perfetto` capture plus a Python `trace_processor` analysis script. If a project already
depends on AndroidX Macrobenchmark for Baseline Profile generation, this is largely wiring up
infra it already has rather than a new dependency.

### A custom static-analysis rule can enforce a "we picked X over Y" convention that's currently only prose

Flagged TaigaMobileNova, 2026-09-01, from reading HedvigInsurance's `Material2Detector` (a custom
Android Lint `Detector`) — not built or verified in any grappim project as of that date. The
general shape, independent of Lint vs. Detekt: resolve each call/reference expression to its
declaring package/class (not text matching, so it survives renames and import aliasing) and flag
it if it matches a banned one, with a `StringOption`-style allow-list for the rare
still-needed exception instead of a blanket ban. Reach for this once a project has a CLAUDE.md-only
convention ("use `ImmutableList`, not `List`, in state classes"; "Ktor only, no second HTTP client")
that review keeps failing to catch — Detekt supports the same shape (a custom `Rule` visiting the
PSI/AST via a `RuleSet` provider). **Check for live drift before writing one**: on 2026-09-01,
TaigaMobileNova's own `ImmutableList` convention (the motivating example) had zero violations across
~50 state classes — a real static-analysis rule for a convention already fully held by every author
by hand isn't worth its setup cost; the pattern is for a convention that's actually getting
violated, not a hypothetical one.
