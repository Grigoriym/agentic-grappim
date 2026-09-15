---
name: grappim-kit-swap
description: Swap a consuming app's local module for a published `grappim-kit-<module>`
  Maven Central artifact — diff the per-platform published sources against the source
  app's current HEAD, update the version catalog and consumer build files, run the full
  gate suite (ktlint, jvmTest, kover, per-platform builds), verify on an emulator when
  the module has runtime behavior, then update `CONSUMING.md`/the checklist and open a
  PR. Use when migrating wallosmobile, TaigaMobileNova, wayprint, or HateItOrRateIt onto
  a `grappim-kit` module, when asked "do the <module> swap", or when checking whether a
  swap someone already did was actually safe.
metadata:
  author: grappim
  keywords:
  - grappim-kit
  - kit swap
  - kit migration
  - maven central
  - sources jar
  - consuming module
  - version catalog
  - ktlintCheck
  - koverVerify
  - CONSUMING.md
---

The repeated procedure behind ~15 module-swap sessions across wallosmobile and
TaigaMobileNova (per `grappim-watcher/docs/CHECKLIST.md`), written down so it's one
command instead of re-deriving the sequence — and re-litigating the same two mistakes —
every time.

This skill is installed for the user account, so it can run in **any** of the grappim
apps or in `grappim-watcher`/`grappim-kit` themselves. It does not know which apps exist
or which modules are wired for publishing — read `grappim-kit/settings.gradle.kts` and
`grappim-kit/CONSUMING.md` for that, every time, rather than assuming last session's list
still holds.

**Hard rule, before touching a single import: an extraction/publish verdict is a
snapshot, not a live link — always re-diff, never trust the label.** `grappim-kit`'s own
`CONSUMING.md` states this as a standing rule for a reason: a module recorded as "canonical,
mechanical swap" can go stale between when it was cut and when you're swapping onto it, or
between one app's swap and the next app's. `grappim-kit-navigation:0.1.0` shipped a
back-stack bug that TaigaMobileNova's own `dev` had already fixed by publish time — caught
only because a session diffed instead of trusting the verdict. Treat every "identical"/
"mechanical" claim — this skill's own past runs included — as something to re-verify, not
cite.

**Second hard rule: the root/umbrella Maven coordinate's sources jar is `commonMain`-only
by KMP design — that is not a broken publish.** `grappim-kit-storage-0.1.4-sources.jar`
containing only `commonMain` (+ `iosMain`, if the module has one) is normal; it does not
mean `androidMain`/`jvmMain` failed to publish. The actual per-target code lives in the
**platform-suffixed** coordinates (`grappim-kit-storage-android`, `grappim-kit-storage-jvm`,
...) — always fetch those for the platforms you're actually diffing, never conclude
anything from the bare root artifact being thin. This was misread as a "broken source
jars" incident twice (`trustmanager`, `storage`) before the pattern was recognized.

## Step 0. Check who owns this repo first

If a Claude session is already open in the target app's own repo, this whole procedure —
investigation included, not just the code change — is the briefing to hand that session
via `SendMessage`, not work to do from here. Don't start editing the app's files locally
and then discover a peer session already had it open; that produced duplicate/conflicting
work at least twice in the sessions this skill is built from. Only run the rest of this
skill inside the app repo directly when no peer session owns it.

## Step 1. Read what's already known about this module

- `grappim-kit/CONSUMING.md`'s section for the module (create the section if this is its
  first swap into any app — every future consumer needs it, not just this one).
- The target app's own `CLAUDE.md` and `docs/EMULATOR_TESTING.md`/equivalent, for
  anything app-specific already recorded.
- `grappim-watcher/docs/SHARED_LIBRARY_PLAN.md` and `docs/CHECKLIST.md`, for which app was
  the extraction's canonical source — the module's design may match one app closely and
  another only superficially (see `navigation`'s wallosmobile/wayprint entry in
  `CONSUMING.md`: same-looking type, `instance`-keyed vs `class`-keyed underneath).

## Step 2. Diff the published module against this app's current HEAD

Group id is `io.github.grigoriym`. For each platform this app actually builds for, pull
that platform-suffixed coordinate's sources jar from Maven Central:

```bash
VERSION=0.1.5   # whatever grappim-kit/gradle.properties' VERSION_NAME currently is
MODULE=storage  # the grappim-kit module name, e.g. storage, navigation, logger, domain
for suffix in "" -android -jvm -iosarm64 -iossimulatorarm64; do
  url="https://repo1.maven.org/maven2/io/github/grigoriym/grappim-kit-${MODULE}${suffix}/${VERSION}/grappim-kit-${MODULE}${suffix}-${VERSION}-sources.jar"
  curl -fsSL -o "/tmp/${MODULE}${suffix}-sources.jar" "$url" 2>/dev/null && \
    unzip -o -d "/tmp/${MODULE}${suffix}" "/tmp/${MODULE}${suffix}-sources.jar" >/dev/null
done
```

A 404 on a given suffix usually just means that platform target doesn't publish its own
artifact for this module (check `grappim-kit`'s own `build.gradle.kts` for the module
before treating it as an error). Diff each unzipped tree against **this app's own current
`origin/<default>`** for the equivalent local module — not against a `grappim-kit`
checkout, and not against whatever the extraction commit said at the time it was cut:

```bash
git -C <app-repo> fetch origin <default-branch>
diff -r "/tmp/${MODULE}-android" <(git -C <app-repo> show "origin/<default-branch>:<path-to-local-module>/src/androidMain")
```

Report every delta found, even a cosmetic one — a same-looking type that's `instance`-keyed
in the app vs. `class`-keyed in the published module is not a compile error, but it can be
a real behavioral divergence (see `navigation` in `CONSUMING.md`). Don't call a swap
"mechanical" until this diff is actually done.

## Step 3. Swap the dependency

- Version catalog: one shared key for every `grappim-kit-*` dependency (`grappimKit` or
  whatever this app already calls it) — never a per-module key. `publish.yml` always
  releases every wired module together at the same `VERSION_NAME`, so per-module keys can
  only drift, never legitimately diverge. If the app already has per-module keys, collapse
  them to one as part of this swap rather than adding another one.
- Replace the local module's `implementation(projects.core.<module>)`-style dependency
  with `implementation("io.github.grigoriym:grappim-kit-<module>:$grappimKitVersion")` in
  every consumer, delete the now-unused local module once nothing references it, and fix
  import ordering/paths at every call site ktlint flags.

## Step 4. Run the full gate suite

Run the whole suite, not just the touched module's own tasks — a module-scoped `jvmTest`
passing says nothing about a different module whose test broke from the same change:

```bash
./gradlew ktlintCheck
./gradlew jvmTest                      # the full suite across all modules, not :module:jvmTest alone
./gradlew koverXmlReport && ./gradlew :koverVerify   # :koverVerify needs the module qualifier
./gradlew :androidApp:assembleGplayDebug -PgplayBuild   # or this app's own Android task name
./gradlew :composeApp:compileKotlinIosSimulatorArm64 --rerun-tasks   # if the app ships iOS
./gradlew :composeApp:packageDistributionForCurrentOS   # if the app ships desktop
```

(Task names above are TaigaMobileNova's; confirm the equivalent names in whichever app
you're in — they follow the same shape but the module/task prefixes differ per app.)

**If a build fails with an OOM/`GC overhead limit exceeded` message rather than a
compiler or test diagnostic, that's the Gradle/Kotlin daemon, not the module change** —
see `mobile-patterns`' Gradle-daemon-OOM entry: `./gradlew --stop` then retry with
`--max-workers=2` before spending time debugging the swap itself.

## Step 5. Emulator verification, if the module has runtime behavior

A pure data/DI-shape module (e.g. a DTO or a Koin module wiring) may not need this; a
module with observable UI or storage/network behavior (navigation, storage, trustmanager,
domain) does. Hand off to the `emulator-testing` skill for the actual device mechanics —
this skill's job is knowing *what* to verify for a kit swap specifically:

- Anything storage-format-related: confirm on a real install, not a fresh/wiped one, if
  the app has ever shipped a version that could hold pre-swap data. A behavior change
  (not just a source diff) needs the app's actual release history checked before calling
  it safe — `storage`'s `KeystoreSecretCipher` swap once corrupted every already-installed
  user's stored value because "no live installs yet" was assumed rather than checked
  against the app's real store listing/tags.
- Anything navigation-related: exercise the actual back-stack behavior end to end (switch
  sections via the drawer, then press back repeatedly), not just that the screen renders —
  a back-stack-shape bug renders identically to the correct behavior in a single
  screenshot.

## Step 6. Land it, but don't merge unsupervised

Commit, push a branch, open a PR into the app's default branch — per the app's own
`CLAUDE.md` for any branch-protection/CI requirements (e.g. wallosmobile requires a green
`guardrails` check against `dev`). **Don't merge until the user has device-tested it** —
that's the standing convention across every swap so far, not just an extra-cautious
one-off. Update:

- `grappim-kit/CONSUMING.md`'s section for the module, with whatever this swap found —
  this is the one place every other app's future swap will actually look, not the app's
  own docs or `grappim-watcher`'s planning docs.
- The app's own `CLAUDE.md`/checklist, if it tracks kit-swap progress.
- `grappim-watcher/docs/CHECKLIST.md`, if this session started from a step there.

## Step 7. Sharpen this skill

If this swap found a gotcha that would apply to *any* app doing *any* future `grappim-kit`
swap (a new sources-jar surprise, a new gate-suite trap, a new coordination miss) —
sharpen this file directly; it's a git checkout at `~/proj/grappim/agentic-grappim`, leave
the edit **uncommitted** for review. A gotcha specific to one module's actual content
(what changed in `navigation`, what `storage`'s cipher prefix does) belongs in
`grappim-kit/CONSUMING.md` instead, per its own convention — not here.
