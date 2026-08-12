---
name: compose-stability-audit
description: Run a Compose Compiler stability audit — wire up opt-in stability reports,
  run them across every Compose UI module, and read/triage the output. Diagnoses "why
  does this composable recompose when nothing changed" by finding unstable classes and
  unstable composable parameters, including the common systemic cause in multi-module
  builds — a domain-layer type that never applies the Compose compiler plugin reads as
  Unstable everywhere downstream regardless of how simple it actually is. Use when the
  user asks about Compose stability, Strong Skipping Mode, recomposition, "why isn't
  this composable skipping", or wants to verify an ImmutableList/stability convention is
  actually being followed rather than just assumed.
metadata:
  author: grappim
  keywords:
  - compose stability
  - compose compiler
  - strong skipping mode
  - recomposition
  - unstable class
  - unstable parameter
  - ImmutableList
  - stabilityConfigurationFiles
  - compose_reports
  - targetKotlinPlatforms
disable-model-invocation: true
---

Runs the Compose Compiler's own stability audit (`*-classes.txt` / `*-composables.txt`
reports) and triages its output. This is a diagnostic pass, not a permanent build step —
wire it as opt-in and gated behind a project property, the same way any other
zero-default-cost audit flag is gated in this build.

**Why this matters beyond "which classes are unstable":** Strong Skipping Mode makes
every composable *skippable*, but an unstable parameter still falls back to referential
(`===`) comparison instead of `.equals()` — so a data class with one unstable field (a
plain `List<T>` where `ImmutableList` was intended) silently recomposes on every
emission even when its content hasn't changed. A convention like "always use
`ImmutableList` in state classes" is only as good as its enforcement; this audit is the
verification tool, showing what the compiler actually inferred rather than what the
convention assumes.

## Step 0. Check whether reports are already wired

Search the build (`build-logic`/convention plugins, or `build.gradle.kts` directly) for
a `composeCompiler { }` block. If one already exists with `metricsDestination`/
`reportsDestination` set behind a flag, skip to Step 2. Otherwise:

## Step 1. Gradle wiring

Add a shared function, gated behind a project property so a default build is
unaffected:

```kotlin
fun Project.configureComposeStabilityReports() {
    if (!project.hasProperty("composeStabilityReport")) return
    extensions.configure<ComposeCompilerGradlePluginExtension> {
        metricsDestination.set(layout.buildDirectory.dir("compose_reports"))
        reportsDestination.set(layout.buildDirectory.dir("compose_reports"))
    }
}
```

Call it right after `apply("org.jetbrains.kotlin.plugin.compose")` (or wherever the
Compose Kotlin compiler subplugin gets applied) — in every convention plugin/module that
applies it, so both a KMP Compose Multiplatform module and a plain Android Compose
module pick it up identically.

**The trap: do not use `targetKotlinPlatforms` to restrict reporting to one target.** In
a KMP module, `commonMain` composables compile once per target (android, iosArm64,
iosSimulatorArm64, jvm, …), so with no restriction every UI module emits one
near-duplicate report set per target. `ComposeCompilerGradlePluginExtension` does expose
a `targetKotlinPlatforms: SetProperty<KotlinPlatformType>` property that looks like the
fix — **it is not just a report-output filter.** Reading
`ComposeCompilerGradleSubplugin.isApplicable()` (decompile the
`compose-compiler-gradle-plugin` jar from the local Gradle cache if you need to confirm
this on a different Compose Compiler version) shows it's what the subplugin uses to
decide whether the Compose compiler plugin applies to a compilation **at all**. Setting
it to `[jvm]` silently disables Compose's bytecode transformation for every other target
in every KMP UI module — confirmed as a real build break, not just a scanning gap: an
Android compile task with the flag set failed with `Internal compiler error... couldn't
find inline method Landroidx/compose/runtime/CompositionLocal;.getCurrent()`. Ship the
function with **no** `targetKotlinPlatforms` set at all, identically at every call site.
Avoid the duplicate-reports problem operationally instead (Step 2): only invoke the
`jvm`-target compile task per module, never a task that also builds Android/iOS. Known
gap this leaves: a composable declared only in an `androidMain` (or equivalent
platform-only) source set is never scanned by a jvm-only run.

If the target app isn't KMP at all (a single-target Android Compose app), there's no
`targetKotlinPlatforms` question — just gate the same extension block behind the
project property.

## Step 2. Run it

```bash
# every Compose UI module's jvm-equivalent compile task, --rerun-tasks is required —
# Gradle does not track -P project properties as task inputs, so an already-UP-TO-DATE
# compile task silently produces no report without this
./gradlew :module-a:compileKotlinJvm :module-b:compileKotlinJvm ... \
  -PcomposeStabilityReport --rerun-tasks

python3 stability-scan.py
```

Find the module list with `grep -rl` for whatever Gradle string marks a Compose UI
module in this build (the convention-plugin alias, or `org.jetbrains.compose` applied
directly) — regenerate it if modules are added or removed rather than trusting a stale
list. `--rerun-tasks` (or deleting `build/compose_reports/` first) matters every time;
forgetting it after a plain, flag-less build silently reports "nothing here."

**Known gap:** running only the `jvm`-target task means any composable declared
exclusively in a platform-only source set is never scanned.

## Step 3. Report file formats

Each module's `build/compose_reports/` contains (exact filenames carry the module
name/project path, so don't hardcode one):

- **`<module>-classes.txt`** — one block per class compiled in that module, each member
  line prefixed `stable`/`unstable`/`runtime` (`runtime` = "depends on a generic type
  argument's runtime stability", e.g. `Uncertain(List)`), with an overall
  `<runtime stability>` verdict line.
- **`<module>-composables.txt`** — one block per `@Composable` (and some non-composable
  top-level functions the compiler still tracked), `restartable`/`skippable` flags, each
  parameter prefixed the same way. **This file is the actionable one** — an unstable
  *class* only matters in practice if it's also an unstable *composable parameter*; a
  class merely stored in a repository or mapper, never passed to a skippable
  composable, doesn't affect recomposition.
- `<module>-composables.csv` — same data as the `.txt`, tabular.
- per-target `<module>-module.json` — raw metrics for Compose's own tooling, not
  human-oriented.

**Verify the exact filenames before hardcoding a glob** — confirmed hyphenated
(`-classes.txt`/`-composables.txt`) on Compose Compiler 2.x; some older
docs/blog-post examples describe an underscored `_classes.txt` form instead.

## Step 4. Run the scan script and triage

`references/stability-scan.py` (stdlib-only, copy it into the project — this is a script
run a few times a year, not a build dependency) walks every module's
`build/compose_reports/`, parses both file types, and prints one line per unstable class
member or unstable composable parameter: `module | class FQN | member: Type` and
`module | fun FQN | param: Type`. Triage from the composables section first, per the
note above.

Two things to check specifically, before reading the raw findings count as the answer:

- **A flat grep for `: List<` misses nested type arguments.** A `Map<K, List<V>>` value,
  not just a top-level `List<T>` field, breaks the `ImmutableList` convention just as
  much — the scan script catches this because it reads the compiler's own verdict, not a
  source-level grep.
- **Zero findings in a spot-check doesn't mean zero findings overall.** A hand-check of
  one module's state classes finding no violations doesn't generalize to the whole repo;
  run the audit before trusting the convention is followed everywhere.

## Step 5. The systemic cause in a multi-module build: unmarked domain types

If most findings trace back not to independent bugs but to one repeated shape — a
handful of domain-layer types (a `data class` with an `ImmutableList` field, otherwise
fully `val`) reported unstable in *every* downstream Compose module that consumes
them — the cause is almost certainly that the module defining those types never applies
the Compose compiler plugin. No stability marker gets embedded for the type, so every
downstream Compose module defaults it to `Unstable` regardless of how simple it actually
is (and a container's instability propagates from its type argument, so
`ImmutableList<TheType>` and even a third-party generic wrapper like a paging library's
`LazyPagingItems<TheType>` report unstable too, for the same reason).

**The fix, and why not the obvious alternatives:**

| Option | Verdict |
|---|---|
| Apply the module's full Compose *UI* convention (Foundation/Material3/Navigation) to the domain layer | Rejected — drags an entire UI toolkit into a layer with zero `@Composable`s |
| `stabilityConfigurationFiles` (a trust-list naming the type as stable) | Works, but is blind trust — no compiler verification if the class later gains a mutable field. Worth it for **third-party** types you can't add a plugin to (see Step 6); overkill for your own domain types |
| Expand a `*UI`-model-plus-mapper pattern so no composable ever sees a raw domain type | Architecturally the cleanest long-term answer, but touches composable signatures across every feature — a multi-session refactor, not this audit's fix |
| **A minimal convention plugin applying only the Compose Kotlin compiler subplugin** | **Chosen.** Real stability marker, no UI toolkit dependency |

The minimal plugin:

```kotlin
// applies ONLY the compiler subplugin, not org.jetbrains.compose (which pulls in the UI toolkit)
plugins.apply("org.jetbrains.kotlin.plugin.compose")

dependencies {
    // needed only so the compiler can reference @StabilityInferred at compile time —
    // downstream UI modules already carry compose-runtime themselves at runtime
    "compileOnly"("org.jetbrains.compose.runtime:runtime:<version>")
}
```

Apply it to every domain module whose types are used as Composable parameters anywhere
in the app. Re-run Step 2's audit afterward to confirm the unstable-parameter count
drops to just the buckets in Step 6.

**Derive the affected module list from a fresh full re-scan, not by hand-tracing field
types from the audit's "unstable parameter" list.** Hand-tracing (starting from the
composables report and manually following which domain module owns each unstable type)
can miss a module whose type only ever shows up as a *class-list* entry rather than
directly in the composables report — e.g. as a field of another state class one level
removed. After fixing the "obvious" set, re-run the audit from scratch and check for
stragglers rather than assuming the hand-traced list was complete; the empirical
fix → re-scan → check loop is cheap and catches what static tracing misses.

## Step 6. Expected, not-actionable findings

These recur across the "third-party/by-design, not a domain-module gap" bucket and
don't need the plugin fix above:

- **`NavController`/`NavHostController`** (and similar third-party framework types) —
  no marker regardless of your own code.
- **`Any`-typed parameters** used by design (a generic drag-and-drop API's item-key
  parameter, for instance) — inherently unstable; narrowing the type is the only fix and
  weakens the API.
- **Third-party library types with no stability marker of their own** (e.g. a
  date/time library's `LocalDate`/`LocalDateTime`) — same "unmarked type defaults to
  Unstable" mechanism as the domain-module gap, but for code you can't add a compiler
  plugin to. This is where `stabilityConfigurationFiles` (deferred in the options table
  above) is the right tool — but only once a second concrete case shows up in your own
  audit; one data point isn't enough to justify a standing config file.

## Considered and usually not worth it up front

- **Always-on reports (no opt-in gate)** — pure I/O/build-time cost for a diagnostic
  useful a few times a year, not every build.
- **A CI gate failing the build on any new unstable class** — premature before a
  baseline audit has run at all; revisit only if a first pass turns up a real, recurring
  problem worth enforcing.
- **A `@NonSkippableComposable` sweep** — needs profiling evidence (a lightweight
  composable eating cycles on `.equals()` over a huge stable graph) to be worth
  anything; don't reach for it from the stability report alone.
