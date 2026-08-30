---
name: mobile-patterns
description: A growing reference of confirmed, project-agnostic Kotlin/KMP mobile architecture facts and platform behaviors — not a procedure to run, a knowledge base to check before answering a coroutines/ViewModel/lifecycle/CI question in any Android or Kotlin Multiplatform project, and to add to whenever an investigation in one project confirms something that generalizes. Check it when reasoning about coroutine exception handling, ViewModel state restoration, or similar cross-cutting mobile-architecture questions.
disable-model-invocation: true
---

# mobile-patterns

Confirmed facts and reusable patterns that came out of investigating one project but hold
generally for Kotlin/KMP mobile apps. Each entry names the project/date it was confirmed in so a
claim can be traced back to its evidence rather than taken on faith.

Read the relevant entry before answering a question in its area. Add a new entry whenever a
project's own investigation turns up something project-agnostic — this is what `finalize` routes
that kind of finding to, per its own Step 3 routing table.

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
