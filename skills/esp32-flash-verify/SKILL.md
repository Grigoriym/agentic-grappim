---
name: esp32-flash-verify
description: Flash an ESP-IDF project onto an ESP32 and prove the board is really
  running the new build before trusting any on-device check — right port and board
  (MAC), a flash that actually completed, the boot log's build hash, and a serial
  capture that works without a TTY (`idf.py monitor` doesn't run under Claude Code).
  Use when asked to flash, upload or deploy firmware, read the boot/serial log, check
  something on the board, or when a device test "passed" or "failed" and you need to
  know which firmware it ran against.
metadata:
  author: grappim
  keywords:
  - esp32
  - esp-idf
  - idf.py
  - flash
  - esptool
  - serial log
  - monitor
  - boot log
  - on-device verify
---

Generic ESP-IDF technique, board- and project-agnostic. A project's own `CLAUDE.md`
holds its port, board, log tags and `tools/serial_log.py`; read it first. On this
machine the shared ESP32 facts (each board's MAC and port, part quirks, the longer list
of traps) live in `~/proj/grappim/grappim-watcher/docs/esp32/` — `parts/` and
`FIRMWARE_PLAYBOOK.md`.

**The failure this skill exists for:** a build that never reached the board, followed by
a device check that "passed" against the old firmware. It happened once already: a
case-sensitive `error` filter hid `Error: app partition is too small`, no `Done` was
printed, and nobody noticed. Every step below is there to make that impossible.

## Step 1. Which board, which port

```bash
ls /dev/tty{USB,ACM}* 2>/dev/null
```

- CP2102 / CH340 boards show up as `ttyUSB*`, CH9102F / native-USB ones as `ttyACM*`.
  The project's `CLAUDE.md` says which.
- No port → the board is unplugged (the user unplugs boards to rewire). Ask for it to
  be plugged in; don't build-and-flash into "port is busy or doesn't exist".
- More than one board, or any doubt which one this is: read its identity without
  writing anything, and compare the MAC with the board's part sheet:

  ```bash
  . ~/esp/esp-idf/export.sh >/dev/null && esptool -p <port> chip-id
  ```

- Two boards running the same firmware answer to the same mDNS name: power one at a
  time when a check goes over WiFi.

## Step 2. Build and flash, and read the result properly

```bash
. ~/esp/esp-idf/export.sh >/dev/null && idf.py -p <port> build flash 2>&1 | tail -40
```

- If you filter the output, filter **case-insensitively**:
  `grep -iE "error|failed|warning|Done|too small"`. A case-sensitive `error` misses
  `Error:`.
- The flash happened only if the output ends with esptool's `Done` (hard reset). No
  `Done` = the old firmware is still running, whatever the build said.
- Transient, retry once: `No serial data received`; a port that vanished mid-flash.
- `Serial data stream stopped: Possible serial noise` → add `-b 115200`.
- `Verification failed after fast reflash ... Reflashing the whole image` after
  switching between two projects' firmware on one board: harmless, it recovers and
  ends in `Done`.
- `sdkconfig.defaults` only takes effect when `sdkconfig` is regenerated: after
  changing it, delete `sdkconfig` and build again.

## Step 3. Capture the boot log without a TTY

`idf.py monitor` fails here ("Monitor requires standard input to be attached to TTY").
Use the project's `tools/serial_log.py` if it has one, with the IDF python env:

```bash
~/.espressif/python_env/idf*_env/bin/python tools/serial_log.py <seconds> "<regex>"
```

(`PORT=<port>` in the environment picks another port, where the script supports it.)
It resets the board via RTS, reads for N seconds with a capped buffer, greps, and
retries once if nothing arrived.

No such script? Do the same thing inline (pyserial from the IDF env): open at 115200,
`dtr=False`, pulse `rts` True→False to reset, read in a loop for a fixed time with a
byte cap, then grep. **Don't** run an open-ended pyserial read loop: that once produced
megabytes of garbled, duplicated output that looked exactly like a crash loop while the
board was fine.

- Always include `overflow|Guru|Backtrace|rst:|BROWNOUT` in the regex, or a panic or a
  power problem gets filtered out with the noise.
- The first read right after a flash or a replug is sometimes empty: retry once.
- The capture resets the board, so whatever was on screen restarts.

## Step 4. Prove it's the new build

Find the boot log's `app_init` lines:

```
app_init: App version:      <short git hash>[-dirty]
app_init: Compile time:     <date time>
```

The hash must match `git rev-parse --short HEAD` (with `-dirty` if the tree has
uncommitted changes), and the compile time must be from this build. Only then does a
device check say anything about the change.

## Step 5. Checks that need the user's hands or eyes

- **Hands** (turn a knob, press a button, plug something): write the steps in the
  reply *before* starting the capture, run the capture in the background with a long
  enough window (~40 s), and read the output when it ends.
- **Eyes** (what's on the screen, which way is up, colours): ask. A screen can keep its
  last image across a reset (SSD1306/SSD1315 OLEDs do), and SPI displays have nothing to
  probe. When a capture contradicts what the user sees, believe the user and recheck
  the capture method.

## Step 6. When it looks broken

- Serial output is unreadable at every baud but esptool connects: it's whatever
  firmware is on the board (e.g. a factory image), not the wiring. Flash, then look again.
- `A stack overflow in task <name> has been detected` right when a feature first runs
  (an HTTPS fetch + JSON parse is the usual one): that task needs a bigger stack, ~8 KB
  for TLS + cJSON.
- `last reset was a BROWNOUT` / repeated resets under load: the supply sagged
  (overload, weak USB port or cable), not a firmware bug.
- New HTTPS host failing with `No matching trusted root certificate found`: check its
  chain with `openssl s_client -showcerts` before touching the code.

Record a new board-level trap in the project's `CLAUDE.md`, or in the shared ESP32 docs
when it isn't project-specific; if it changes how flashing or capturing is done
everywhere, sharpen this skill instead.
