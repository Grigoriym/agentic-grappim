---
name: emulator-testing
description: Drive a real Android emulator via adb to verify that a change actually
  works on device — headless boot, screenshots with correct coordinate scaling,
  `uiautomator dump` for reliable taps, form filling, process-death vs config-change
  testing, and reading a Ktor/network debug log. Reads and maintains a project-local
  `docs/EMULATOR_TESTING.md` holding that project's own package id, AVD name, activity
  name and app-specific gotchas. Use when asked to verify something on the
  emulator/device, when a checklist or PR's Verify step needs a running app, or when
  the user says "check this on the emulator", "screenshot the app", "test this on
  device".
metadata:
  author: grappim
  keywords:
  - emulator
  - adb
  - uiautomator
  - screenshot
  - device testing
  - on-device verify
  - process death
  - am kill
  - force-stop
  - frame timing
  - perfetto
  - gfxinfo
---

Generic Android/adb technique for verifying a change on a real emulator, written
package-name-agnostic so it applies to any KMP/Android project. It does **not** know
this project's package id, AVD name, screens or app-specific quirks — that lives in
`docs/EMULATOR_TESTING.md` in the current repo, which this skill reads first and keeps
up to date.

## Step 0. Read the project doc

Look for `docs/EMULATOR_TESTING.md` (check the project's `CLAUDE.md` for a different
path first — some projects point elsewhere). If it exists, read it before doing
anything: it has the concrete package id(s), activity name, AVD name and the app's own
previously-discovered gotchas, which turn every recipe below from a template into a
runnable command.

If it does not exist, create it from the template in Step 5 the first time this skill
verifies something in this project — fill in the package id, activity name and AVD name
by reading the app's `build.gradle.kts`/manifest and `~/Android/Sdk` (`emulator
-list-avds` for the AVD name if it isn't already recorded anywhere).

## Step 1. Boot and screenshot

**Check `adb devices -l` before assuming a bare `adb`/`./gradlew installXxx` call reaches
the AVD.** A real phone connected over USB is a device too, and if it's the only one
attached, an install task and every unqualified `adb` command silently go to *it* instead
of the emulator — with no error to flag the mix-up. Worse, it may be screen-locked with a
PIN nobody here has: a screenshot of a PIN pad is not the AVD failing to boot, it's the
wrong device answering. Don't try to unlock or guess a PIN on hardware that isn't this
setup's own test device. Boot the AVD explicitly and pass every subsequent command
`-s <avd-serial>` (`emulator-5554` by default) once more than one device might be present,
rather than relying on adb's single-device default.

Headless, no snapshot, no interaction needed beyond `input tap`:

```bash
~/Android/Sdk/emulator/emulator -avd <avd-name> -no-snapshot-save -no-boot-anim \
  -gpu swiftshader_indirect &
adb wait-for-device shell 'while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done'
adb shell am start -n <package-id>/<fully-qualified-activity-name>
adb exec-out screencap -p > shot.png   # then read shot.png; tap with `adb shell input tap X Y`
adb emu kill                           # don't leave it running
```

`am start -n` needs the **fully-qualified** activity name (no leading dot) the moment
the package id carries a build-flavor suffix — the class itself isn't renamed, only the
package. If the app ships multiple flavors/variants with different application ids,
pick one for day-to-day verification (they're usually identical besides the id) and
record which in the project doc rather than re-deriving it every session.

## Step 2. Tap accurately

**`screencap`'s image is scaled relative to the device's real pixel grid.** Coordinates
read off a screenshot need multiplying by the device's scale factor before they're fed
to `input tap` — get that factor once (compare a screenshot's dimensions to `adb shell
wm size`) and record it in the project doc. This is easy to forget mid-session once a
few taps in a row used *already-scaled* coordinates pulled from a `uiautomator dump` —
the two coordinate spaces look identical in a tool call and nothing errors when they're
mixed, a tap just lands on whatever was underneath.

`adb shell uiautomator dump /sdcard/window_dump.xml && adb pull /sdcard/window_dump.xml`
sidesteps the arithmetic entirely: its `bounds="[x1,y1][x2,y2]"` values are already in
real device pixels, so a center computed from them needs no scaling. Reach for the dump
over eyeballing the screenshot whenever a tap is going into a dialog, a dropdown menu, or
any screen where several fields sit close together — the cost of one dump is lower than
the cost of a mis-tap that fails silently.

Three dump-specific gotchas worth knowing before trusting a grep against it:

- **A day in a `DatePickerDialog` calendar grid is addressed by `content-desc`**
  (e.g. "Friday, August 14, 2026"), not by the visible digit's `text` — grepping for the
  digit finds the wrong node and a mistap lands on a different day with no visible error
  until the field is checked afterward.
- **A custom field built from a `readOnly` `OutlinedTextField` plus a transparent
  click-overlay `Box`** — the usual Compose shape for a field that opens something other
  than the keyboard (a menu, a date picker) — can make its own placeholder text
  invisible to the dump's text search while the field is empty, unlike a plain text
  field's placeholder. The field is still there and still tappable; compute its centre
  from the screenshot or from surrounding fields' known spacing rather than trusting an
  empty grep to mean "not rendered yet".
- **An `ExposedDropdownMenuBox` anchor's clickable region is the entire field box**,
  label to bottom border, not a narrow strip around the value text — its
  `clickable="true"` bounds in the dump are usually noticeably taller than they look in
  a screenshot.

## Step 3. Fill a form

**Tap the first field once, then `input keyevent KEYCODE_TAB` between fields** if the
framework honors TAB for focus (Compose does). Re-tapping by coordinate goes wrong the
moment the keyboard opens and shifts the layout, or the moment validation adds/removes
content between fields — a mis-tap lands on whatever moved into that spot. Re-screenshot
before trusting stale coordinates on any screen where content can grow (an inline
warning, a notice banner) between one field and the next.

**`input text` needs a `sleep 1` after each field**, or a long value arrives
**truncated** — which then fails validation in a way that reads exactly like a wrong
value and sends debugging in the wrong direction. Compare the field's visible content
(dot count for a password, character count for text) against a screenshot of a
known-good attempt before believing a validation error is about the *value* rather than
the *input method*.

Clearing a field to retry: `input keycombination 113 29` (Ctrl+A) then
`input keyevent KEYCODE_DEL`. On the last field, `input keyevent KEYCODE_ENTER` often
submits the form if it wires `ImeAction.Done` to the submit action — cheaper than
hunting for a submit button's coordinates under an open keyboard, worth trying before
assuming it doesn't apply.

**A fresh emulator boot can pop a first-run tutorial** (a stylus tutorial on some Pixel
AVDs, a setup wizard screen) **over the first field tapped**, and it eats every tap
after with no error — it has its own dismiss control, not a system back gesture.
Screenshot before trusting that a field actually received what was typed right after a
cold boot.

## Step 4. Prove behavior, not just appearance

A handful of methodological points that keep a screenshot from proving something it
doesn't:

- **To find out which of two overlapping causes produced an effect, diverge them.** If a
  UI value could come from either a stored preference or the system/window default, a
  screenshot where both happen to agree proves nothing about which one the app actually
  reads — set them to disagree first, then a single screenshot has one explanation.
- **A list backed by a local cache renders identically whether the last network refresh
  succeeded, failed, or never ran.** A screenshot of populated rows is not evidence a
  request happened; read the network debug log for that (below), or force a state where
  cache and server are known to disagree (clear local storage/log back in against a
  different backend) before trusting what's on screen.
- **A state that only exists while a network call is in flight** is caught by
  backgrounding the tap that triggers it, not by sleeping first:
  `adb shell input tap X Y &` then immediately `adb exec-out screencap -p > shot.png`.
  Pick the widest window available (the attempt with the longest visible delay/backoff)
  for the most reliable capture.
- **Grep the request/response log *lines*, never the whole log tag.** A verbose HTTP
  logger interleaves full response bodies with everything else, burying the one line
  that matters. Narrow the grep to the literal markers the logger uses (e.g.
  `REQUEST:|RESPONSE: |failed with exception`), and `adb logcat -c` immediately before
  the action under test so old lines don't get credited to it.
- **"Don't keep activities" is not a process-death test.** It recreates the activity
  inside the same still-running process, so anything that only breaks when the process
  itself is rebuilt passes it anyway. The real check backgrounds the app and kills the
  process:

  ```bash
  adb shell input keyevent KEYCODE_HOME && adb shell am kill <package-id>
  adb shell monkey -p <package-id> -c android.intent.category.LAUNCHER 1
  ```

  `am kill` keeps the task and any saved-instance-state; `force-stop` discards both. Pick
  the one that matches what's under test — `am kill` for in-memory back stack / UI
  `rememberSaveable` state, `force-stop` for anything that has to survive a full cold
  start from disk (a local database, a persisted preference).

  **Run the kill cycle once, from a clean task.** Every `monkey … LAUNCHER` launch after
  an `am kill` *adds* an activity instance to the existing task rather than replacing it,
  and once there is more than one, a relaunch starts a fresh activity instead of
  restoring the killed one — so a second or third cycle in the same session restores
  nothing and reads as a regression that isn't real. `adb shell am force-stop
  <package-id>` first to reset the task, relaunch, navigate back to the screen under
  test, and only then background + `am kill`. `dumpsys activity activities | grep
  <package-id>` (the `sz=`/`numActivities` count) tells you which situation you're in.
  An outbound link (a browser opened from inside the app) leaves the same kind of dirty
  multi-activity task behind — `force-stop` both apps before starting a cycle that
  follows one.
- **Coordinates and in-memory state don't survive a process boundary either.** If
  filters, sort order, or list position live in memory, a `force-stop` + relaunch can
  bring the same screen back in a *different* arrangement — re-screenshot after every
  relaunch rather than reusing a pre-kill coordinate.

## Step 4b. Frame-level timing — when a screenshot can't tell you *how long*

A screenshot (or even a "screenshot right after backgrounding the tap") answers "does it
render." It cannot answer "does it render *fast*," and eyeballing "screen A feels slower
than screen B" is unreliable enough to get corrected by real data — reach for one of
these instead of trusting the impression.

**Quick look — `dumpsys gfxinfo`'s raw per-frame timestamps, zero setup:**

```bash
adb shell dumpsys gfxinfo <package-id> reset
adb shell input tap X Y
adb shell dumpsys gfxinfo <package-id> framestats > out.txt
```

Despite the `framestats` argument, the interesting part is a `---PROFILEDATA---` block
containing a CSV header and one row per frame with real nanosecond timestamps
(`HandleInputStart`, `AnimationStart`, `PerformTraversalsStart`, `DrawStart`,
`FrameCompleted`, …). `FrameCompleted − HandleInputStart` of the last row is a screen's
real tap-to-settled time — cheap enough to run for both sides of an "A feels slower than
B" question before touching any code. **The last row in a short capture can carry stale
values from the ring buffer** (a `FrameCompleted`/`GpuCompleted` timestamp far smaller
than the row's own `SwapBuffers` — a dead giveaway) for a frame whose GPU-side fields
were never populated; use `SwapBuffersCompleted` instead when that happens.

**Deeper look — Perfetto, when you need to know *why*, not just *how long*:**

```bash
adb shell perfetto -o /data/misc/perfetto-traces/t.perfetto-trace -t 8s \
  sched freq idle am wm gfx view input dalvik hal res memory binder_driver &
sleep 1.5   # let tracing actually start before the action under test
adb shell input tap X Y
sleep 5     # >= the -t duration minus the head start, or the pull races the writer
adb pull /data/misc/perfetto-traces/t.perfetto-trace
```

**Don't pull immediately after your own sleeps add up to `-t`'s duration** — the on-device
process needs a moment past that to flush and close the file; a pull that races it
silently grabs a 0-byte file with no error. Check the file size (or just `ls` it on
device) before trusting a pull, and re-pull once it's stopped growing.

Analyze with the `perfetto` Python package's `TraceProcessor` (`pip install perfetto` —
use a venv, `pip` refuses a bare install as "externally managed" on most distros; the
first `TraceProcessor(...)` call downloads a `trace_processor_shell` binary from Google
over the network):

```python
from perfetto.trace_processor import TraceProcessor
tp = TraceProcessor(trace='t.perfetto-trace')
```

Two things that aren't obvious from the schema:

- **The main thread's name is truncated to 15 chars by the Linux `comm` field and is
  usually *not* `"main"`** — it's the tail end of the package name instead (e.g.
  `losmobile.debug` for `com.grappim.wallosmobile.debug`). Filter `thread` by
  `tid = <pid>` (the main thread's tid always equals the process pid), not by name.
- **`thread_state.state = 'S'` (sleeping) and `'Running'` mean opposite things for a
  "why is this slow" question, and only one of them is a code bug.** A long `Running`
  span is the thread genuinely busy computing something — that's a real stall, and the
  overlapping `slice` rows (join on `thread_track.utid`) name what it was doing. A long
  `S` span is the thread idle, blocked on I/O or simply out of work — completely normal
  while waiting on a network response, and *not* evidence of a blocking bug no matter how
  long it lasts. Check `state` before concluding a gap in rendered frames means the main
  thread is stuck; it usually means the opposite.

**Forcing a state that depends on real, variable timing — don't race it, force it.**
Trying to screenshot an in-flight/loading state by timing `sleep` against a real
network's actual latency wastes attempts the moment that latency isn't constant (a local
dev server's response time can vary 10ms to 700ms+ run to run, and adb's own
shell-dispatch overhead adds more jitter neither side accounts for). Cut connectivity
*before* the action instead, so the in-flight state is guaranteed to hold open long
enough to screenshot at leisure:

```bash
adb shell cmd connectivity airplane-mode enable
adb shell svc wifi disable
# ... trigger the action, screenshot whenever ...
adb shell cmd connectivity airplane-mode disable
adb shell svc wifi enable
```

This exercises the failure path rather than a slow success, but visually the loading
state looks identical either way and this is the only version of the screenshot you can
actually land on the first try. (`adb root` does not work on standard AVD system images
— "cannot run as root in production builds" — so an iptables-based packet-drop, which
would preserve the success path by hanging instead of failing, isn't available; network
toggling is the practical option.)

## Step 5. Networking, storage, and other device mechanics

- **`localhost` from the emulator is the emulator itself** — reach the host machine at
  `10.0.2.2` (e.g. a local dev server on `:8080` is `http://10.0.2.2:8080` from the
  app). If commands run through a sandboxed Bash tool that blocks loopback, `curl` to
  `127.0.0.1`, `adb`, and the emulator process itself typically all need the sandbox
  disabled for this project's local backend — reflect that in the project doc rather
  than rediscovering it.
- **Toggling network reachability**: `adb shell cmd connectivity airplane-mode enable` /
  `disable`, give it a few seconds either way. An emulator can carry two networks that
  both report internet capability, so a connectivity-change callback can fire twice —
  the *second* firing is the real state; a listener that reads only the first callback
  and stops can misreport connectivity as broken when it isn't.
- **Rotation**:
  ```bash
  adb shell settings put system accelerometer_rotation 0   # or the AVD ignores the next line
  adb shell settings put system user_rotation 1            # 1 = landscape, 0 = portrait
  adb shell settings put system accelerometer_rotation 1   # put it back when done
  ```
- **Theme/dark-mode check is a pixel read, not an impression**:
  `python3 -c "from PIL import Image; print(Image.open('shot.png').convert('RGB')
  .getpixel((X, Y)))"` against a known coordinate is the only reliable way to tell two
  screenshots apart when they differ by one color role, and it's what makes a *crop* at
  2x worth taking for something like a dark-on-dark status bar that's invisible at
  full-page scale.
- **Flipping night mode does not disturb the running screen**: `adb shell cmd uimode
  night yes` / `no` recreates the activity but keeps the back stack and any transient
  surface (an open dialog/sheet usually survives) — capture a state once, flip the mode,
  capture the other, instead of driving the app back to the same state twice. A request
  already in flight survives it too.
- **Planting local storage state before its UI exists** lets a storage-layer step verify
  on device without waiting for the screen that would normally set it. The concrete
  technique depends on the storage format (DataStore Preferences is an unchecksummed
  protobuf `map<string, Value>` that merges on repeated writes, so a single encoded entry
  can be *appended* to the file to set one key without disturbing the rest; a SQLite-backed
  store takes a direct `sqlite3`/`content` write instead) — record the concrete recipe
  once worked out for a given project in that project's own doc, since the encoding is
  file-format-specific. Whatever the mechanism, **force-stop the app first**, or the
  running process overwrites the file on its own next write. And note the quoting: `adb`
  flattens its arguments into one string that the *device's* shell re-parses, so inner
  single quotes get stripped and a `$VAR` expands device-side — use outer double quotes,
  no shell variables, and an absolute path (`run-as` does not leave you in the app's own
  data directory).
- **Picking a gallery image for an upload flow needs the file media-scanned first**, and
  a single-select system picker may still show a multi-select-style confirmation bar.
  `adb push`ing a file into `/sdcard/Pictures/` does not make it appear in a
  `GetContent()`-style picker on its own —
  `adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d
  file:///sdcard/Pictures/x.jpg` is what registers it with MediaStore. And depending on
  the picker's version, tapping a thumbnail may only *select* it — tapping an explicit
  **Done**/confirm control is what actually returns the `Uri` to the app.
- **A launcher icon lives in the app drawer, not necessarily the home screen** on
  launchers that only pin favorites to home — `adb shell input swipe 540 1800 540 600`
  (adjust to the device's resolution) pulls the drawer up. That swipe can silently no-op
  about as often as it works, with no error either way — screenshot after every attempt
  and retry rather than trusting a single call. `pm clear`/`force-stop` does not open or
  close the drawer; it's independent launcher state.

## Step 6. Write down what's new

If this session found a gotcha specific to *this* app (a screen's own field ordering, a
component that hides its placeholder from the dump, a particular error string), add it
to `docs/EMULATOR_TESTING.md`, following the template below. If it found something that
would apply to *any* Android/Compose app regardless of package — a new dump quirk, a new
launcher behavior, a new adb technique — sharpen this skill instead: edit this file
directly (it's a git checkout at `~/proj/grappim/agentic-grappim`) and leave the edit
**uncommitted** for the user to review with `git diff` before it reaches other projects.
Don't add a project-specific fact here, and don't leave a generic technique stranded in
one project's doc where the next project won't find it.

## The project doc template

```markdown
# <Project> — Emulator testing

Project-specific facts for the `emulator-testing` skill. Generic adb/uiautomator
technique lives in the skill itself, not here — this file is only what's true about
*this* app.

## Device facts

- AVD: `<avd-name>`
- Package id(s): `<package-id>` (<flavor>), ...
- Activity: `<fully-qualified-activity-name>`
- Backend/local server, if any: `<how to reach it from the emulator, e.g. 10.0.2.2:port>`

## App-specific gotchas

<one bullet per discovered quirk — a screen whose fields grow during validation, a
component whose placeholder the dump can't see, an error string that misleads, a
storage-planting recipe with concrete keys/paths for this app's own format>
```
