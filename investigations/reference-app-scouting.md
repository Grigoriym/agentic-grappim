# Reference-app pattern scouting (temporary investigation)

**Status: scratch / active.** Not a skill, not a permanent doc — read "How to use this
doc" before touching it.

## Purpose

gregory + various Claude Code sessions across grappim projects occasionally read through
other, unrelated Android/KMP codebases (open source, work-adjacent, or otherwise
well-regarded) looking for conventions, architectural rules, or gotchas worth stealing.
This file is the single place those findings land before gregory decides what to do with
them: promote into [`skills/mobile-patterns`](../skills/mobile-patterns/) (confirmed,
project-agnostic facts), promote into one specific project's `CLAUDE.md`, fold into a new
or existing shared skill, or discard.

This file is a queue, not a knowledge base — `mobile-patterns` is the knowledge base for
things that have already been confirmed as generally true. Nothing in here is an
established convention until gregory triages it. The file is meant to be temporary: once
its backlog is fully triaged, delete it (or narrow it down to only the entries still
awaiting a decision).

## How to use this doc

**Scanning a new repo (adding a section):**

1. Add a new `## <repo name>` section (or add to an existing one if re-scanning the same
   repo from a different angle) with: local path or URL, a one-line stack/tech summary,
   the date scanned, and which project/session prompted the scan.
2. Under it, add one entry per candidate pattern using the template below. **Append
   only** — don't rewrite or resolve another session's entries.
3. Don't implement anything found here directly in the project you're working on. This
   is scouting, not an approved backlog — wait for gregory to read an entry and decide.

**Triaging (gregory, or a session gregory points at this doc):**

- Set an entry's `Status` line to `Adopted → <where it landed>` or `Declined — <reason>`.
  Leave `Not triaged` alone if no decision has been made yet.
- When an entry is adopted, do the actual work (edit `CLAUDE.md` / `mobile-patterns` /
  etc.) as its own change, then update the `Status` line to point at where it landed.
- Once every entry under a repo section is triaged, that section can be deleted from this
  file.

## Entry template

```
### <Pattern name>

- **Source:** `<repo path or URL>`, `<file:line or module>`
- **Applies to:** <which project(s)/stacks this is relevant for>
- **What it is:** <1-3 sentences>
- **Why it might be worth it:** <the concrete problem it solves or regression it prevents>
- **Status:** Not triaged
```

## Findings

### HedvigInsurance (`/home/gregory/proj/HedvigInsurance`)

- **Stack:** Android (not KMP) — Jetpack Compose, Apollo GraphQL, Metro DI
  (compile-time), real Navigation 3 (`androidx.navigation3`), Molecule/MVI presenters,
  ~80+ Gradle modules.
- **Scanned:** 2026-09-01, prompted from a TaigaMobileNova session, looking for anything
  transferable to grappim KMP apps.
- **Note:** most of Hedvig's stack is deliberately different from grappim projects
  (Metro vs Koin, Apollo vs Ktor+DTOs, Molecule/MVI vs the per-field-callback ViewModel
  style TaigaMobileNova has already chosen instead) — filtered down to the handful of
  ideas that are stack-agnostic.
- **Rescanned:** 2026-09-01, from a WallosMobile session, same repo — looking for
  anything transferable to a much smaller (single-app, no feature-module isolation yet)
  KMP project. Same filtering logic applies, plus WallosMobile already uses real
  Navigation 3 (from MealieMobile) so the nav-specific entry below is new this pass.
- **Rescanned:** 2026-09-01, from the TaigaMobileNova session, following up on three
  leads the WallosMobile pass flagged but didn't write up (coordinated directly between
  sessions rather than through this doc). Added the enforcement-mechanism detail below
  and two new entries; skipped the feature-flag lead (neither project has flags yet) and
  the Crashlytics-Apollo-specific part of the logging lead (generalized instead, see
  below).
- **Verification pass:** 2026-09-01, from the TaigaMobileNova session — went back through
  every entry below and checked each one's actual applicability against Taiga's real
  code (grep/read, not guesswork), rather than leaving them all as untested "might apply"
  claims. Result: 2 of 6 entries turned out to already be fully honored or the wrong
  fit for Taiga's architecture (one marked Declined with the counter-evidence, one
  strengthened to "near-zero-cost adopt" since it's already true in practice); the rest
  got a concrete "checked, here's what's actually true here" note added rather than
  staying purely speculative. This is the kind of pass a session should do before
  gregory triages an entry, if it has the time and the target project checked out.
- **Verification pass:** 2026-09-01, from the WallosMobile session — checked the two
  generic (non-Hedvig-stack-specific) entries against WallosMobile's own code, prompted
  by the TaigaMobileNova session's parallel pass. "Never leak the wire type": zero `Dto`
  leaks found, near-zero-cost adopt (same conclusion as Taiga). "Comment discipline":
  found two real violations in source (not docs), so same "would have real teeth, not
  free" conclusion as Taiga, though the specific comments differ.
- **Triage pass:** 2026-09-01, from the TaigaMobileNova session, at gregory's request
  ("is there a plan for that investigation, let's add it to our plan"). Landed the two
  ready items: the DTO-leak rule (zero-cost, just codified) and the comment-discipline
  rule (gregory chose "adopt as-is, rewrite the violations" over a carve-out or
  declining). Grouped the three no-current-trigger nav entries (markers, `navigateUp`
  split, deep-link aggregation) into one `docs/revisit.md` #46 entry rather than three
  separate ones, since they share a trigger. Left the feature-module-isolation entry
  Declined (already was) and the three remaining low-priority tooling entries
  (dependency graph, Detekt allow-list rule, Gradle module auto-discovery) un-queued —
  none has a concrete trigger, so a `docs/revisit.md` entry for them would just be noise;
  they stay here for whenever that changes.
- **Triage pass:** 2026-09-01, from the WallosMobile session, gregory said "yep" to
  making the same calls Taiga did. Landed the same two ready items for WallosMobile
  (DTO-leak rule codified; comment-discipline rule adopted as-is and its two violations
  rewritten) and the same `docs/revisit.md` #5 grouping for the three no-trigger nav
  entries. One addition beyond a straight port: the comment-discipline rule picked up an
  explicit "a `plan §N` citation is not a history reference" carve-out that Taiga's
  version didn't need — WallosMobile's comments cite `docs/IMPLEMENTATION_PLAN.md`
  pervasively (~60 sites) as their normal way of citing rationale, and the rule as
  literally stated would otherwise read as banning that whole convention. Worth another
  session's eyes if this carve-out ever looks like it's being used to smuggle a real
  history/process comment past the rule — it's meant for stable-doc citations only.
- **Correction:** 2026-09-01, from the WallosMobile session, prompted by the
  TaigaMobileNova session flagging that its own audit had missed bare task-number
  citations (a phrasing-blind grep gap, 8 extra violations found and fixed in TaigaMobileNova,
  PR #377). Ran the equivalent broader grep here and found the *same citation shape* the
  `plan §N` carve-out already covers, just pointing at a different doc: ~226 sites citing a
  `docs/CHECKLIST.md`/`docs/archive/CHECKLIST-DONE.md` step number (`(3.11)`, `M26:`, and
  16 `--- N.N: description ---` test-file section dividers). Unlike Taiga's case, this
  wasn't a missed *violation* — it's the same deliberate provenance-citation convention as
  the plan-citation carve-out, just uncovered by that carve-out's exact wording. Extended
  the carve-out in `CLAUDE.md` to name checklist-step citations explicitly (already pushed
  to the open PR, not yet merged) rather than rewriting 226 sites. Spot-checked every hit
  that also matched a narration keyword (`no longer`/`replaced`/`instead of`) and confirmed
  each describes current behavior, not code history — so the wider carve-out doesn't launder
  a real violation the way a blind rewrite would have risked missing the *opposite* problem.
  No additional real violations found beyond the original two.

#### Comment discipline: ban history/migration/rejected-alternative comments

- **Source:** `CLAUDE.md`, "Comments" section
- **Applies to:** any project's `CLAUDE.md` — generic code-comment policy
- **What it is:** an explicit rule that comments must describe only the *current* code
  and stand alone, with no reference to history ("replaces X…"), rejected alternatives
  ("…not Y"), or conversation/process state ("for now", "TBD"). Test given: "would this
  make sense to someone reading cold, with no knowledge of the PR?"
- **Why it might be worth it:** sharper than most projects' one-line "avoid comments"
  rule. Directly extends the "no correction breadcrumbs" convention TaigaMobileNova
  already applies to docs — this would close the same gap for code comments.
  **Checked against TaigaMobileNova (2026-09-01):** the rule would have real teeth, not
  just a hypothetical one — grepped for history/process-referencing comments and found
  two `jvmTest` file headers that this rule would flag:
  `feature/issues/ui/.../IssuesScreenTest.kt:22-31` and
  `feature/scrum/ui/.../ScrumBacklogScreenTest.kt:22-31` both cite task numbers from
  `docs/testing/improvement-plan.md` ("Paging sweep, task 21…", "same reasoning as task
  18") and one narrates a fix ("previously returned `emptyFlow()`… fixed to the common
  baseline"). These read as deliberate continuity aids for the coverage-sweep multi-session
  work (CLAUDE.md's Multi-Session Work section explicitly values that kind of
  traceability elsewhere, just in `CHECKLIST-DONE.md`/`IMPLEMENTATION_PLAN.md`, not in
  source comments) — so adopting Hedvig's rule verbatim would mean relocating this
  context out of the test files, not just banning sloppy comments. Worth gregory's eyes
  specifically because of that tension, not a slam-dunk adopt.
  **Checked against WallosMobile (2026-09-01):** grepped source comments (not docs) for
  history/process/rejected-alternative language. Two clear hits: `build-logic/convention/
  .../KmpNetworkConventionPlugin.kt:16` ("Android is the only target *for now*; the Darwin
  and CIO engines go here when `configureKmp()` gains those targets" — textbook
  process-state comment, explicitly the banned "for now" case) and
  `feature/setup/ui/.../LoginScreen.kt:150` ("(plan §1.1). It *replaces* the path toggle
  below *rather than joining it*" — a rejected-alternative framing citing an external plan
  section). Two more are borderline, not clear violations:
  `core/api/.../CompositeTrustManager.kt:107` ("as hostname verification itself *used to*")
  reads as general X.509/TLS domain history, not this codebase's own change history, so it
  passes the "make sense to someone reading cold" test even though it contains "used to";
  `core/api/.../PlatformHttpClientEngine.kt:20` ("this *replaces* chain trust, nothing
  else") is describing which security property the line affects, not a design alternative
  rejected. Net: same shape of tension as Taiga's finding — the rule would have real
  teeth here too, and would require touching a couple of real comments, not free to adopt.
- **Status:** Adopted (TaigaMobileNova) → `CLAUDE.md`'s new "Comments" subsection (under
  Coding Guidelines), 2026-09-01, adopted as-is with no carve-out — gregory's call after
  seeing the two real violations above. Rewrote both flagged files
  (`IssuesScreenTest.kt`, `ScrumBacklogScreenTest.kt`): dropped the task-number/history
  references, kept the underlying non-obvious *current* facts (why `substring = true` is
  needed, why the "Add" topbar action isn't tested here, the paging-flow shape) rewritten
  to stand alone. Both files' `jvmTest` and `ktlintCheck` still green after the rewrite.
  **Correction (2026-09-01, same session):** the initial audit's grep only checked
  history/rejected-alternative *phrasing* and missed the narrower "cites a bare task
  number" shape — a broader `grep -rlnE '//.*\btask [0-9]+\b'` repo-wide found **8 more**
  violations (`SettingsAboutScreenTest`, `SettingsInterfaceScreenTest`,
  `TrustedCertificatesScreenTest`, `ProjectValuesScreenTest`, `ProjectSelectorScreenTest`,
  `ScrumOpenSprintsScreenTest`, `ScrumClosedSprintsScreenTest`, `EpicsScreenTest`) — same
  shape, all in the coverage-sweep test files. Fixed the same way; repo-wide grep for the
  pattern now returns nothing. Worth remembering when auditing for this rule elsewhere:
  grep for the *citation shape* ("task N", "step N", a checklist filename), not only for
  history-language keywords — the two miss different things.
  **Also landed for WallosMobile**, 2026-09-01 → `CLAUDE.md`'s new "Comments" subsection
  (under Coding guidelines). Adopted as-is, with one addition Taiga's version doesn't
  need: an explicit carve-out stating that a `plan §N`/API-doc-§N citation is *not* a
  history reference (it points at a permanent rationale doc, not at what a PR changed),
  because WallosMobile's comments cite `docs/IMPLEMENTATION_PLAN.md` sections pervasively
  (~60 sites, grepped) as their standard way of pointing at non-obvious "why" — the rule
  as stated would otherwise read as banning that whole established convention, which
  isn't what it's for. Rewrote the two flagged files' comments
  (`KmpNetworkConventionPlugin.kt`, `LoginScreen.kt`) to drop the "for now"/rejected-
  alternative framing while keeping the plan citations and the underlying non-obvious
  facts. `ktlintCheck` green on both touched modules after the rewrite.

#### Explicit "never leak the wire type" rule

- **Source:** `CLAUDE.md`, "Data Layer" section — Apollo-generated types are banned from
  public interfaces/return types; every repository/use-case maps to a project-owned type
  before returning, even when the wire shape is already a perfect fit.
- **Applies to:** any project with a data/domain split and a network layer producing
  DTOs — TaigaMobileNova, MealieMobile, HateItOrRateIt, WallosMobile
- **What it is:** a named, explicit rule (not just implied by folder layout) that DTOs
  must never appear outside the data layer's internal impl classes.
- **Why it might be worth it:** the data/domain/ui split already implies this in these
  projects, but it's never spelled out as a rule anywhere. Easy regression path (a repo
  method accidentally typed to return a DTO into a ViewModel) that a one-line CLAUDE.md
  rule would catch in review even with no tooling behind it.
  **Checked against TaigaMobileNova (2026-09-01):** grepped every `Repository`/`UseCase`
  interface across `feature/` for a `Dto` type anywhere in the declaration — zero hits.
  The convention is already fully honored in practice, project-wide, purely by the
  data/domain/dto/mapper module split holding the line without anyone writing the rule
  down. That makes this a near-zero-cost adopt (codifying something already true, not
  fixing a live problem) rather than a rule that would change any code today.
  **Checked against WallosMobile (2026-09-01):** same result — grepped every `.kt` file
  for a `Dto` type appearing outside a `dto`/`mapper` directory or a `Mapper` class; zero
  hits. `WallosError`/`WallosEnvelopeParser`'s "everything that leaves `core:api` is a
  `WallosError`" rule (already in `CLAUDE.md`) reinforces the same boundary from the
  error-type side. Also a near-zero-cost adopt here — nothing to fix, just naming a
  convention the module layout already enforces by construction.
- **Status:** Adopted (TaigaMobileNova) → `CLAUDE.md`'s "Feature Module Structure"
  section, 2026-09-01. **Also landed for WallosMobile**, 2026-09-01 → `CLAUDE.md`'s
  Architecture section (new bullet ahead of the "Shell" bullet), same free-adopt shape —
  zero violations to fix, just naming the boundary the module split already holds.

#### Build-time feature-module isolation enforcement

- **Source:** `CLAUDE.md`, "Critical architectural rule" — a convention plugin
  (`configureFeatureModuleGuidelines()`) fails the build if a `feature-*` module depends
  on another `feature-*` module, with one documented carve-out for `-navigation` modules.
- **Applies to:** any multi-module project with a `feature/` layer and a stated (but
  currently doc-only) isolation rule — worth checking per-project whether it's actually
  enforced or just written down.
- **What it is:** Gradle-level enforcement instead of a doc-only convention. Mechanism
  (`build-logic/convention/.../HedvigGradlePlugin.kt`, `configureFeatureModuleGuidelines()`):
  applied per-module, it hooks `configurations.configureEach { resolutionStrategy { eachDependency { ... } } }`
  and `require()`s that no dependency whose Gradle module name matches the project's
  `feature-*` convention is requested, unless that dependency's name ends `-navigation`.
  Fails at resolution time, inside the *offending* module's own build — not a separate
  root-level audit task — so the error surfaces exactly where the bad `implementation(...)`
  line was added.
- **Why it might be worth it:** matches the "Determinism Over Process" philosophy
  already in TaigaMobileNova's `CLAUDE.md` (`guardrails.yml` is the existing example of
  this) — a rule that's currently only prose is a natural candidate for the same
  treatment, if it isn't enforced already. The `eachDependency` mechanism is generic
  Gradle API, not Hedvig-specific tooling — portable to any convention-plugin setup.
  **Checked against TaigaMobileNova (2026-09-01):** doesn't transfer as-is. Grepped
  every `feature/*/*/build.gradle.kts` for `projects.feature.*` dependencies and found
  pervasive, intentional feature-to-feature coupling — e.g. `feature/tasks` depends on
  `issues`, `epics`, `userstories`, `sprint`, `history`, `users`, `workitem`, `filters`,
  `projects`; `feature/epics` depends on `filters`, `workitem`, `users`, `history`,
  `projects`, `userstories`. This isn't drift from an unstated isolation rule — Taiga's
  `feature/*` modules are decomposed by *layer* (ui/domain/data/mapper/dto) within a
  business domain, and those domains reference each other's models directly (an epic
  has user stories, a task has an assignee from `users`, etc.), unlike Hedvig's
  `feature-*` modules which are meant to be independent vertical slices reached only via
  a `-navigation` carve-out. Applying Hedvig's rule here isn't "add enforcement to a
  policy we already follow" — it would require restructuring the module graph itself.
- **Status:** Declined — the isolation *policy* Hedvig enforces doesn't hold for
  TaigaMobileNova's module graph; extensive cross-feature dependency is the deliberate
  architecture, not an unenforced rule. The `eachDependency` mechanism itself stays a
  reasonable pattern to reach for if Taiga ever adopts a *different* doc-only rule that
  should be enforced (see the guardrails.yml precedent) — just not this one.

#### Nav-key marker interfaces for cross-cutting screen behavior

- **Source:** `CLAUDE.md`, "Navigation (Navigation 3)" — `navigation-common` declares
  small marker interfaces (`TopLevelTabRoot`, `DeepLinkAncestry`,
  `CrossSellEligibleDestination`, `SuppressesChatPushNotification`,
  `DeliberateLogoutOrigin`) that a `HedvigNavKey` opts into. The app shell (`:app`)
  branches on these interfaces to decide tab-root behavior, synthetic back-stack
  reconstruction on deep link, cross-sell sheet eligibility, etc. — without importing
  anything from the owning feature module.
- **Applies to:** any project on real Navigation 3 with more than one thing the shell
  needs to know about a screen (WallosMobile, MealieMobile) — not useful for a
  single-property need, only once a shell starts asking "does this screen do X" for
  more than one X.
- **What it is:** instead of a shell-level `when (key) { ... }` or a single boolean
  field bolted onto every key, cross-cutting screen properties are separate marker
  interfaces a key opts into; the shell does `key is ThatInterface` checks. Composable
  (a key can implement several), and adding a new cross-cutting concern doesn't touch
  every existing key.
- **Why it might be worth it:** WallosMobile has no deep links or tab-parking yet, so
  nothing to change today — but the moment either lands, this is the pattern to reach
  for rather than inventing a shell-side special case per screen. Noted so a future
  session doesn't re-derive it from scratch.
  **Checked against TaigaMobileNova (2026-09-01):** same conclusion holds, for the same
  reason. `composeApp/.../main/MainAppState.kt` identifies top-level keys with one
  hardcoded `Set<NavKey>` (`TOP_LEVEL_KEYS`), built from direct imports of every
  feature's `NavDestination` — that's exactly right for the *one* cross-cutting need
  Taiga's shell currently has. No deep-link handling, no "suppress X while showing this
  screen" concern exists yet to justify marker interfaces over the simpler Set. Same
  trigger condition as WallosMobile: revisit only once a second such shell-level
  question shows up (a deep-link feature would be the likely trigger, given
  `Navigator`'s `resetTo`/`replaceCurrent` primitives already exist to build on).
- **Status:** Adopted (TaigaMobileNova) → tracked, not implemented, in
  `docs/revisit.md` #46 ("No deep-link readiness plan yet"), 2026-09-01 — grouped there
  with the two entries below since all three share the same trigger (deep links being
  added). **Also landed for WallosMobile**, 2026-09-01 → `docs/revisit.md` #5, same
  title and same grouping (this entry plus the two below) — WallosMobile's
  `core/navigation/.../Navigator.kt` has the same single-`goBack()`-primitive shape as
  Taiga, no deep-link code anywhere yet, same trigger to revisit on.

#### Dependency graph / unused-resource tooling

- **Source:** `CLAUDE.md`, Essential Setup Commands —
  `./gradlew :generateProjectDependencyGraph` (needs graphviz) and
  `./gradlew :app:lint -Prur.lint.onlyUnusedResources` / `removeUnusedResourcesDebug`
- **Applies to:** any multi-module Android/KMP app
- **What it is:** off-the-shelf Gradle tasks for visualizing the module graph and
  finding unused resources.
- **Why it might be worth it:** minor tooling convenience; low cost to wire up if the
  underlying plugins are already reachable. Not investigated further than noticing it
  exists.
- **Status:** Partially adopted (TaigaMobileNova) → the dependency-graph half only, PR
  [#378](https://github.com/Grigoriym/TaigaMobileNova/pull/378), 2026-09-01. Turned out
  not to be a plugin at all — it's a plain Groovy script
  (`gradle/projectDependencyGraph.gradle`, applied via `apply(from = ...)`), originally
  from `chrisbanes/tivi`, that walks the project tree and shells out to Graphviz. Ported
  directly with the module-kind detection re-pointed at TaigaMobileNova's actual plugin
  ids (KMP/Android-app/plain-`kotlin("jvm")` instead of Hedvig's KMP/Android/JS/Java) —
  confirmed working, correct per-module coloring on a live run. The unused-resource half
  (`removeUnusedResourcesDebug`) is untouched — that's an Android Lint task tied to
  Android resource XML specifically; not investigated whether/how it'd apply to a KMP
  project with Compose Resources instead of `res/`.

#### Custom static-analysis rule banning a deprecated/wrong-layer API, with an allow-list

- **Source:** `hedvig-lint/src/main/kotlin/com/hedvig/android/lint/Material2Detector.kt` —
  a custom Android Lint `Detector` (UAST-based) that resolves each call/reference
  expression's package and errors if it's `androidx.compose.material` (Material 2,
  superseded by M3 in this codebase), with a `StringOption` allow-list for APIs that have
  no M3 equivalent yet. Registered via `HedvigLintRegistry` and shipped as its own Gradle
  module (`hedvig-lint`) applied to every module.
- **Applies to:** any project that has picked one library/pattern over another
  project-wide and wants that decision enforced, not just documented — e.g. Ktor over a
  banned second HTTP client, `ImmutableList` over plain `List` in state classes (a rule
  TaigaMobileNova's `CLAUDE.md` already states but doesn't enforce), or any "we migrated
  off X, don't reintroduce it" rule.
- **What it is:** the general shape, independent of Android Lint specifically — a custom
  static-analysis rule that flags usage of a banned package/API by resolved reference
  (not text matching, so it survives renames/aliasing) and ships with an escape-hatch
  allow-list instead of a blanket ban, so a genuinely-needed exception doesn't require
  disabling the whole rule.
- **Why it might be worth it:** TaigaMobileNova already uses Detekt, which supports the
  same shape (a custom `Rule` visiting the PSI/AST, with a `RuleSet` provider) — this
  would be a Detekt custom rule, not a port of Hedvig's Lint code. Worth it only if a
  currently-prose-only convention (e.g. the `ImmutableList` one above) turns out to be
  violated often enough in review that automating the check pays for the setup cost —
  not verified either way, just noting the pattern exists and where the prior art is.
  **Checked against TaigaMobileNova (2026-09-01):** picked the `ImmutableList` example
  itself and grepped all ~50 `*State` data classes in `feature/` for a plain `List`/
  `MutableList` field — zero hits, convention fully held. So the specific example named
  above wouldn't currently justify writing the Detekt rule (nothing to catch). That
  doesn't kill the general pattern — a custom Detekt rule is still the right tool *if*
  some other prose-only convention turns out to have live drift — but this doc's
  motivating example for Taiga specifically doesn't hold up under a real check.
- **Status:** Not triaged

#### Downgrade log priority for expected/unauthenticated errors before crash reporting sees them

- **Source:** `app/logging/logging-public/.../Logcat.kt` — an overload of `logcat(...)`
  taking an `ApolloOperationError` instead of a raw `Throwable`; if
  `operationError.containsUnauthenticatedError` it clamps the priority to at most `WARN`
  before delegating to the normal `logcat`, so an expected 401-shaped GraphQL error never
  reaches Crashlytics as `ERROR` regardless of what priority the call site asked for.
- **Applies to:** any project logging network/API errors through a single facade that
  forwards `ERROR`-priority logs to a crash reporter — TaigaMobileNova specifically:
  `core/logger`'s `logcat`, whose `CrashlyticsTree` forwards every `ERROR`+throwable call
  verbatim (see `CLAUDE.md`'s Error Handling section, which already has a sanitization
  pass for raw exception *messages* at this exact boundary — this is the same boundary,
  a different axis: which errors should be `ERROR` at all, not what their message reveals).
- **Why it might be worth it:** Taiga's API is also token-auth'd, so an expired/revoked
  token produces the same "expected, not exceptional" 401 shape on API calls — the
  motivating problem is real in principle. **Checked against TaigaMobileNova
  (2026-09-01):** already effectively solved, by a different mechanism.
  `core/api/.../errors/ErrorMappingPlugin.kt` maps any HTTP ≥400 response into a typed
  `NetworkException` and rethrows it immediately (`catch (e: NetworkException) { throw e }`,
  ahead of the generic `catch (e: Exception)` that logs at `ERROR`) — so an expected
  API-error response never reaches the `ERROR` log path at all.
  `core/api/.../TokenRefreshPlugin.kt`'s "still unauthorized after retry, logging out"
  case likewise logs with no explicit priority (defaults to `DEBUG`, not `ERROR`); the
  only `ERROR` log in that file is a genuine failure (the token-refresh network call
  itself throwing). Hedvig's priority-clamping trick and Taiga's typed-exception split
  solve the same problem from opposite ends (downgrade after the fact vs. never
  classify an expected response as loggable-as-error in the first place) — Taiga's
  is arguably the sounder version since it can't be forgotten at a new call site the way
  a manual priority clamp could. Did not check every `LogPriority.ERROR` call site
  project-wide, only the network layer.
  **Checked against WallosMobile (2026-09-01):** also a non-issue, by a third
  mechanism — `core/domain/.../ResultExtension.kt`'s `resultOf` (the sole catch point
  every repository uses around a Wallos API call) doesn't log at all, at any priority;
  it only turns the caught exception into `Result.failure(e)`, which the UI layer later
  renders via `getErrorMessage()`. So `WallosError.Unauthenticated`/`NotFound` (the
  auth/ownership-failure cases) never reach any `logcat` call, let alone `ERROR`. The
  only `LogPriority.ERROR` calls in the whole repo (`grep`, non-test) are both in
  `WallosEnvelopeParser.kt`, for a genuinely malformed/non-JSON response body — a real
  parse failure, not an expected auth/network error. Confirms the pattern isn't needed
  here either, for a reason neither Hedvig's nor Taiga's mechanism relies on: nothing
  downstream of an expected error is a logging call site at all.
- **Status:** Declined — TaigaMobileNova's network layer already keeps expected
  HTTP-error responses out of the `ERROR` log path via a different, arguably more
  robust mechanism (typed exception + early rethrow vs. priority clamp). No action
  needed unless a future audit finds an `ERROR` log firing on a genuinely-expected
  condition outside the network layer.

#### `navigateUp` reserved for the top-bar back arrow only; everything else uses a plain pop

- **Source:** `CLAUDE.md`, "Critical navigation rule" — `backstack.navigateUp()` may
  only be wired to a screen's top-app-bar back arrow; every "done"/"close"/"continue"
  button, success screen, or programmatic pop uses `backstack.popBackstack()` instead.
  Reason given: `navigateUp` carries deep-link/synthetic-stack semantics (it can rebuild
  a parent stack when the user arrived via a lone deep link) that are correct for the
  system "up" affordance but wrong for an in-content button — mixing them makes a
  button's behavior depend on how the screen was *reached*, and can diverge from
  predictive/system back.
- **Applies to:** any back-stack navigation system where "up" and "back" are allowed to
  mean different things (i.e. once any kind of synthetic/deep-link-reconstructed stack
  exists) — not applicable to a system with only one pop primitive.
- **What it is:** a naming/usage discipline, not a mechanism — the two operations exist
  as genuinely different methods, and the rule is about which UI affordance is allowed
  to call which one.
- **Why it might be worth it:** **Checked against TaigaMobileNova (2026-09-01):**
  `core/navigation`'s `Navigator` (`Navigator.kt`) has exactly one back primitive,
  `goBack()` — no separate deep-link-aware `navigateUp()`, and no evidence of deep-link
  handling anywhere in the codebase (grepped for it while checking a different entry
  above). So there's no semantic split for a rule to protect right now; this bug class
  can't occur. Logging it anyway because it's a real, well-reasoned footgun for the
  moment TaigaMobileNova ever adds deep links or any other synthetic-backstack feature
  (a task deep link from a push notification, say) — if `Navigator` grows a second
  "smarter" pop method at that point, this is the naming/usage discipline to copy
  *before* the first content button gets wired to it by habit.
- **Status:** Adopted (TaigaMobileNova) → tracked, not implemented, in
  `docs/revisit.md` #46, 2026-09-01 (grouped with the nav-key-markers entry above and
  the deep-link-matcher entry below — all three share one trigger). **Also landed for
  WallosMobile**, 2026-09-01 → `docs/revisit.md` #5, same grouping — confirmed
  WallosMobile's `Navigator.goBack()` is likewise the only pop primitive today.

#### Deep-link matcher aggregation + pending-deep-link-while-logged-out queue

- **Source:** `CLAUDE.md`, "Deep Links" section — each feature builds `DeepLinkMatcher`s
  from its own URI patterns and contributes them into one app-wide aggregated matcher
  (via a multibinding); `MainActivity` forwards raw `ACTION_VIEW` URIs down a channel;
  a matched key is routed through the nav controller once logged in, or held as a single
  `pendingDeepLink` and landed after login if the app was logged out when the link arrived.
- **Applies to:** any project that might add deep links (push-notification-driven
  navigation, universal/app links) later — not urgent for a project with none today.
- **What it is:** three separable ideas: (1) each feature owns and contributes its own
  URL-matching rules instead of a central registry hardcoding every feature's patterns,
  (2) a deep link arriving before the app has finished resolving auth state is queued as
  at most one pending target rather than dropped or racing the login flow, (3) the
  `DeepLinkAncestry` marker (already noted in the nav-key-markers entry above) supplies
  the synthetic parent stack so a deep-linked screen doesn't strand the user with no way
  to navigate "up" into the section it logically belongs to.
- **Why it might be worth it:** speculative — TaigaMobileNova has no deep links today
  (not checked exhaustively, but no evidence found while scanning `core/navigation` and
  `MainAppState.kt`). Recording the shape now so a future session adding deep links
  (e.g. "open this task from a push notification") doesn't have to invent the
  logged-out-queueing behavior from scratch — that's the part most likely to be gotten
  wrong first try (a naive implementation either drops the link or crashes navigating
  before the graph is ready).
- **Status:** Adopted (TaigaMobileNova) → tracked, not implemented, in
  `docs/revisit.md` #46, 2026-09-01 (grouped with the two nav entries above). **Also
  landed for WallosMobile**, 2026-09-01 → `docs/revisit.md` #5, same grouping.

#### Auto-discover Gradle modules instead of hand-listing every `include(...)`

- **Source:** `CLAUDE.md`, "Module Discovery" — "All directories under `app/` with
  `build.gradle.kts` are included [in `settings.gradle.kts`]... No need to manually
  register new modules." (Micro-apps are the one deliberate exception, included by hand.)
- **Applies to:** any multi-module Gradle project whose `settings.gradle.kts` is a long
  hand-maintained list of `include(...)` calls.
- **What it is:** `settings.gradle.kts` walks the module directory tree looking for
  `build.gradle.kts` files and calls `include(...)` programmatically, instead of one
  literal line per module.
- **Why it might be worth it:** **Checked against TaigaMobileNova (2026-09-01):**
  `settings.gradle.kts` is 118 lines, one hand-written `include(":...")` per module
  (feature/core/utils/tools, ~110+ modules), no auto-discovery. The papercut this fixes
  is low-severity (Gradle fails loudly and immediately if a new module's `include` line
  is forgotten — it's friction, not a correctness risk), so this is a convenience call,
  not a "we found a bug" call. Tradeoff worth naming: auto-discovery also removes the
  ability to comment out or selectively exclude one module without moving it out of the
  scanned tree — Hedvig itself keeps micro-apps on the manual list for exactly that kind
  of control. Only worth doing if the 118-line file is actually felt as a maintenance
  annoyance; not chasing this further without that signal.
- **Status:** Not triaged

## Repos not yet scanned

(none queued yet — add candidates here as they come up)
