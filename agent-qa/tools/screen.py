#!/usr/bin/env python3
"""The executor's eyes: one call = screenshot + tappable elements + new crashes + a11y check.

  screen.py <dir> <NN>

Saves <dir>/<NN>.png at HALF size (cheaper to read) and prints every element that has a
label or is a text field, with its centre in REAL device pixels, ready for
`adb shell input tap X Y`. Then prints crashes logged since the previous call, and
clickable nodes with no label or a touch target under 48 dp.
Pick the device with ANDROID_SERIAL when more than one is attached.
Adapted from mobile-agent-testers' scripts/android/screen.py (MIT).
"""
import io
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image


def adb(*a, raw=False):
    r = subprocess.run(["adb", *a], capture_output=True, timeout=60)
    return r.stdout if raw else r.stdout.decode("utf-8", "replace")


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    out, nn = Path(sys.argv[1]), sys.argv[2]
    out.mkdir(parents=True, exist_ok=True)

    png = adb("exec-out", "screencap", "-p", raw=True)
    png = png[png.find(b"\x89PNG"):] if b"\x89PNG" in png else png
    img = Image.open(io.BytesIO(png)).convert("RGB")
    w, h = img.size
    img.resize((w // 2, h // 2)).save(out / f"{nn}.png")
    print(f"screenshot: {out}/{nn}.png (device {w}x{h}; image is half size: "
          f"multiply positions read on it by 2; the centres below are already device pixels)")

    adb("shell", "uiautomator", "dump", "/sdcard/aq_dump.xml")
    xml = adb("exec-out", "cat", "/sdcard/aq_dump.xml")
    try:
        root = ET.fromstring(xml[xml.find("<"):])
    except ET.ParseError:
        root = ET.Element("hierarchy")
        print("(no UI tree: the screen may be animating; call again)")

    dpi_m = re.findall(r"\d+", adb("shell", "wm", "density"))
    density = (int(dpi_m[-1]) if dpi_m else 160) / 160
    unlabeled, small = [], []
    for n in root.iter("node"):
        text = (n.get("text") or "").strip()
        desc = (n.get("content-desc") or "").strip()
        b = list(map(int, re.findall(r"\d+", n.get("bounds", ""))))
        if len(b) != 4:
            continue
        x1, y1, x2, y2 = b
        cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
        field = n.get("class", "").endswith("EditText")
        clickable = n.get("clickable") == "true"
        enabled = n.get("enabled") != "false"
        if text or desc or field:
            kind = "field" if field else ("button" if clickable else "text")
            state = "" if enabled else " [disabled]"
            if n.get("checked") == "true":
                state += " [checked]"
            if n.get("selected") == "true":
                state += " [selected]"
            print(f'- {kind} "{(text or desc)[:80]}" centre=({cx},{cy}){state}')
        if clickable and x2 > x1 and y2 > y1:
            labelled = text or desc or any(
                (c.get("text") or c.get("content-desc") or "").strip() for c in n.iter("node"))
            if not labelled:
                unlabeled.append(f"({cx},{cy})")
            if min(x2 - x1, y2 - y1) / density < 48:
                small.append(f'"{(text or desc)[:30]}" ({cx},{cy})')

    if unlabeled or small:
        parts = []
        if unlabeled:
            parts.append(f"{len(unlabeled)} clickable with no label at " + ", ".join(unlabeled[:6]))
        if small:
            parts.append(f"{len(small)} touch target(s) under 48 dp: " + ", ".join(small[:6]))
        print("accessibility check: " + "; ".join(parts) + " (confirm on the screenshot)")

    # Only the crash buffer is read and cleared: the main buffer holds the Ktor request
    # lines the runner's checks count, so it must never be cleared from here.
    crash = adb("logcat", "-d", "-b", "crash")
    adb("logcat", "-b", "crash", "-c")
    lines = [x for x in crash.splitlines() if x.strip() and not x.startswith("-----")]
    # System-image noise (e.g. a uwb HAL that crashes in a loop) isn't the app's: with
    # AQ_PACKAGE set, only crash lines from the app's own pid(s) are shown.
    pkg = os.environ.get("AQ_PACKAGE")
    if pkg and lines:
        pids = set(adb("shell", "pidof", pkg).split())
        pids |= set(re.findall(rf"Process: {re.escape(pkg)}, PID: (\d+)", crash))
        lines = [x for x in lines if any(re.search(rf"\b{p}\b", x) for p in pids)]
    if lines:
        print("ERRORS SINCE LAST SCREENSHOT:\n" + "\n".join(lines[-15:]))


if __name__ == "__main__":
    main()
