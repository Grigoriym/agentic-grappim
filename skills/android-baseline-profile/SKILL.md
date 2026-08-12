---
name: android-baseline-profile
description: Set up an Android Baseline Profile / Macrobenchmark module to remove
  JIT warm-up jank on cold navigation, or diagnose why an existing one isn't helping.
  Wires a `com.android.test` producer module, writes `BaselineProfileRule` journeys,
  and confirms `androidx.profileinstaller` actually applies the generated profile at
  install time rather than assuming generation alone is enough. Use when the user
  wants to add a Baseline Profile, mentions macrobenchmark, cold-start/cold-navigation
  jank that tracing already pinned on JIT lock-contention, or "the baseline profile
  doesn't seem to be doing anything."
metadata:
  author: grappim
  keywords:
  - baseline profile
  - macrobenchmark
  - profileinstaller
  - jit warm-up
  - cold start
  - cold navigation
  - android performance
  - dexopt
  - speed-profile
---

Wires up an Android Baseline Profile: a list of hot classes/methods AOT-compiled at
install time instead of waiting for the JIT to warm up cold-navigation and scroll
paths. This is the fix for one specific failure mode, not a general performance skill
— see Step 0.

## Step 0. Confirm this is the right fix before paying the setup cost

A Baseline Profile only helps **JIT re-compiling this process's own cold code paths
under a lock the render thread contends on.** Confirm that mechanism first:

- A Perfetto trace showing `Lock contention on Jit code cache for mutator` slices, or
- A `dumpsys gfxinfo`/`framestats`-measured gap between a screen's cold-process time
  and its warm (already-navigated) time.

The `emulator-testing` skill's Step 4b covers capturing either. If tracing points
somewhere else instead — a slow network call, a heavy synchronous computation, a
Compose recomposition storm — fix that; a Baseline Profile does not touch it, and
building the module below on a hunch instead of evidence is real Gradle-wiring cost
for possibly nothing.

**Capture the `VerifyClass`/JIT-cold evidence on the same build variant a profile would
actually ship on (R8-minified release), not debug.** R8 shrinking on release can already
strip most of the class graph that costs `VerifyClass` time on an unshrunk debug build —
confirmed on a real device: a debug build showed a 289ms worst frame dominated by
`VerifyClass` slices, but the same journey on the release build showed near-zero
`VerifyClass` cost (2 slices, 0.10ms total) with or without a profile installed. The
debug-build finding didn't transfer; there was nothing left on release for a Baseline
Profile to amortize. Re-run Step 0's evidence-gathering against a release build before
committing to this fix.

## Step 1. Add the producer module

It's the one module type that is neither a KMP target nor a shared-convention-plugin
consumer — a plain Gradle Android Test module, wired by hand. Known gotchas, confirmed
live rather than assumed from docs:

- **Check `androidx.benchmark`/`androidx.baselineprofile`'s AGP compatibility before
  picking a version.** A "documented-stable" release can lag current AGP by a full
  major version and fail to apply at all (`Module :app is not a supported android
  module`) — its module-detection logic simply doesn't know about the newer AGP yet. A
  later, even-`-beta`, release can configure and run cleanly where the "stable" one
  can't. Re-check this pin whenever AGP is bumped; don't assume last time's version
  still applies.
- **Both `com.android.test` and `androidx.baselineprofile` need `alias(...) apply
  false` in the root `build.gradle.kts`'s plugin-dedup block**, next to
  `com.android.application`. Skip it and applying either from the module's own
  `plugins {}` block with an explicit version fails with `already on the classpath
  with an unknown version` — any subproject that applies `com.android.application`
  already puts every AGP plugin class (including `com.android.test`'s) on the shared
  classloader, and a second, versioned request for an already-loaded class can't be
  compatibility-checked.
- **If the target app has product flavors, the benchmark module needs a matching
  flavor dimension of its own, by name.** A plain subproject script can't import the
  target app's Kotlin flavor-declaration objects the way an in-repo convention plugin
  can. Left unflavored, the target app's flavor-qualified release variants become
  ambiguous to this module's own unflavored one — `generateXBaselineProfile` fails
  with a Gradle variant-attribute-ambiguity error between the flavors'
  `RuntimeElements`.
- **A convention plugin's `configureLinting()`-style helper isn't callable from a
  plain subproject script** — an import that resolves inside a compiled build-logic
  module doesn't resolve from a bare module's `build.gradle.kts`. detekt/ktlint need
  configuring by hand here, including any Compose-lint ruleset dependency a shared
  detekt config requires — if that config has a Compose-specific section, it's invalid
  without the plugin present in *every* module that runs detekt against it, regardless
  of whether the module itself has Compose code.
- **Generation runs against a real connected device** (`baselineProfile {
  useConnectedDevices = true }`) — reuse whatever AVD/device on-device verification
  already uses rather than provisioning a separate Gradle Managed Device.
- **The target app module needs the `androidx.baselineprofile` *consumer* plugin too, not
  just this producer module.** Without `alias(libs.plugins.androidx.baselineprofile)` in
  the app module's own `plugins {}` plus `baselineProfile(projects.benchmark)` in its
  `dependencies {}`, `generate<Variant>BaselineProfile` doesn't exist as a task on the app
  module at all — there's nowhere for the generated profile to land, even though the
  `@Test` lives in this producer module and runs fine on its own.
- **Watch AVD disk space once this module coexists with debug/release builds.** A
  debug build, a release build, a `nonMinifiedRelease` benchmark variant and a
  `connectedAndroidTest` target APK together can fill a default (often 6G) data
  partition fast, and a Gradle-driven macrobenchmark run then fails with
  `IOException: Requested internal only, but not enough space` — `adb shell df /data`
  confirms this before assuming the test itself is broken. Editing
  `disk.dataPartition.size` in the AVD's `config.ini` does **not** resize an
  already-created `userdata-qemu.img`; relaunch with both `-wipe-data` and
  `-partition-size <MB>` together to actually recreate it larger.

### Gradle shape

```kotlin
// benchmark/build.gradle.kts
plugins {
    alias(libs.plugins.android.test)
    alias(libs.plugins.androidx.baselineprofile)
    alias(libs.plugins.detekt)
    alias(libs.plugins.ktlint)
}

android {
    namespace = "com.example.app.benchmark"
    compileSdk = /* … */

    defaultConfig {
        minSdk = /* … */
        targetSdk = /* … */
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    targetProjectPath = ":app"   // the module under benchmark

    // Only needed if the target app has flavors — mirror its dimension/flavor names.
    flavorDimensions += "STORE"
    productFlavors {
        create("gplay") { dimension = "STORE" }
        create("fdroid") { dimension = "STORE" }
    }
}

baselineProfile {
    useConnectedDevices = true
}

dependencies {
    implementation(libs.androidx.test.ext.junit)
    implementation(libs.androidx.test.uiautomator)
    implementation(libs.androidx.benchmark.macro.junit4)
}
```

`gradle/libs.versions.toml`:

```toml
androidxBenchmark = "<version>"   # also versions the androidx.baselineprofile plugin
androidx-benchmark-macro-junit4 = { module = "androidx.benchmark:benchmark-macro-junit4", version.ref = "androidxBenchmark" }
androidx-baselineprofile = { id = "androidx.baselineprofile", version.ref = "androidxBenchmark" }
android-test = { id = "com.android.test", version.ref = "agp" }
```

## Step 2. Write the generator

`BaselineProfileRule` drives real UI journeys through `MacrobenchmarkScope`
(uiautomator underneath) and records which classes/methods get touched. One `@Test`
per journey worth its own profile coverage — cold start, plus whatever screen Step 0's
tracing flagged as JIT-cold:

```kotlin
class BaselineProfileGenerator {
    @get:Rule
    val baselineProfileRule = BaselineProfileRule()

    @Test
    fun coldStart() = baselineProfileRule.collect(packageName = TARGET_PACKAGE) {
        pressHome()
        startActivityAndWait()
    }

    @Test
    fun listFling() = baselineProfileRule.collect(packageName = TARGET_PACKAGE) {
        pressHome()
        startActivityAndWait()
        openList()
        repeat(3) { device.swipe(540, 2000, 540, 300, 150) }
    }
}
```

Gotchas found writing journeys like this:

- **If a login/auth screen gates the journey and the stored credential is encrypted**
  (Android Keystore or similar), a DataStore/SharedPreferences-planting trick to seed
  it won't work — a planted value that doesn't decrypt just reads as "nothing stored,"
  not a crash. Log in once by hand on the same device before running the generator
  instead.
- **`BaselineProfileRule` kills the process between iterations but does not clear app
  data** — a manually seeded login survives every `@Test` within one Gradle
  invocation, but the target app is uninstalled at the end of every
  `connectedXInstrumentedTest` run, pass or fail. Re-login is needed before every
  fresh generator invocation, not just once ever.
- **A journey that depends on a view appearing only once some async state resolves**
  (a button whose text/icon renders after a load) needs an explicit
  `device.wait(Until.hasObject(...))` before interacting with it —
  `startActivityAndWait()` only waits for the window to go idle, not for the app's own
  first-frame async state. A journey that happens to land on a fast frame will pass
  without this wait; a slower cold-JIT frame makes `findObject` return null and the
  test flaky, not reliably failing.

## Step 3. Run it, and where the output lands

```bash
./gradlew :app:generateXReleaseBaselineProfile
```

writes `app/src/xRelease/generated/baselineProfiles/baseline-prof.txt`, committed as
source (not gitignored — a release build reads it from there without regenerating).
The assembled release APK embeds the compiled form at `assets/dexopt/baseline.prof` +
`.profm` (confirm with `unzip -l` if this needs re-checking).

**This task is a real `connectedAndroidTest` run** — it boots instrumentation,
installs both the target app and the test APK, and drives the device. It can take
several minutes; run it as a background task rather than under a short foreground
timeout, or a slow run gets silently cancelled with no result printed.

## Step 4. Make sure the profile is actually applied — the step it's easy to skip

Generating the file is necessary but **not sufficient**. A plain `adb install` (or any
non-Play-Store install path, e.g. an F-Droid-style flavor) does not automatically
apply Baseline Profile compilation. This is the single most common way a "did the
Baseline Profile fix it" measurement goes silently wrong: the installed APK's dexopt
status reads `[status=verify] [reason=install]` — the profile is compiled into the
APK but was never applied to the installed copy — and re-measuring at that point just
re-confirms the *original*, unoptimized number while looking like a real check.

**Fix: add `androidx.profileinstaller` as a runtime dependency of the app module.**

```toml
profileinstaller = "<version>"
androidx-profileinstaller = { module = "androidx.profileinstaller:profileinstaller", version.ref = "profileinstaller" }
```

```kotlin
// app/build.gradle.kts
dependencies {
    implementation(libs.androidx.profileinstaller)
}
```

Its bundled `ProfileInstallerInitializer` (an `androidx.startup` initializer, no
manual wiring) fires automatically on first launch after install, and the system's
background dexopt job then compiles the profile in — confirm via `adb logcat` for the
initializer firing, and `dumpsys package` moving to `[status=speed-profile]
[reason=bg-dexopt]`. Real devices run that job on idle+charging; force it immediately
for verification instead of waiting:

```bash
adb shell cmd package bg-dexopt-job
adb shell dumpsys package <package-id> | grep status   # re-check after this
```

## Step 5. Re-verify against the original complaint, not a proxy

**When the re-verification is a before/after A/B (not just "did it get better"), the
"before" capture must never have had `cmd package compile` called on it, not even with
`-m verify`.** `cmd package compile -m verify -f` runs `dex2oat`'s verification pass ahead
of time and writes the result into the vdex — exactly the cost a plain `adb install`
otherwise leaves for ART to pay lazily on every cold start. Forcing it before the "before"
capture (even intending a neutral baseline) eliminates the very `VerifyClass` cost the A/B
exists to measure, and both sides then read as "already fast" for the wrong reason. Start
"before" from a genuinely untouched install (`adb uninstall` then `adb install`, confirm
`dumpsys package <id> | grep status` shows `[status=verify] [reason=install]`) and only
call `cmd package compile -m speed-profile -f` for "after."

Re-measure with the `emulator-testing` skill's Step 4b technique, against the
**same** journey the original complaint named — not a different screen that happened
to be convenient to trace. Confirmed on a real device in one project: fixing the
unapplied-profile gap above took a cold-navigation worst-frame time from 150ms to
117ms, a real ~22% reduction — but a separate scroll-jank complaint traced in the same
investigation did **not** improve from the same fix. A Baseline Profile fixes the
JIT-cold mechanism it targets, not every "feels slow" finding that happened to surface
alongside it in the same trace session — don't assume one fix explains every symptom
just because tracing found both at once.

## Notes

- Debug builds never carry a Baseline Profile — the generated file lives only in the
  release-flavor source set, so a debug-build re-check can't confirm or refute a fix
  either way. Confirm which variant is actually being measured before trusting a
  result.
- `dumpsys package <package-id> | grep status` is the fast sanity check any time a
  "we shipped a Baseline Profile and it doesn't seem to help" report comes in — check
  it before re-profiling from scratch.
