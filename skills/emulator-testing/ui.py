#!/usr/bin/env python3
"""Tap by text, from a fresh uiautomator dump. Bounds are device pixels: no scaling.

  ui.py list                 every node with text or content-desc, and its bounds
  ui.py tap "<text>" [n]     tap the n-th (0-based) node whose text or content-desc equals <text>

Pick the device with ANDROID_SERIAL (adb reads it) when more than one is attached.
"""
import re
import subprocess
import sys


def dump():
    d = subprocess.run(["adb", "shell", "uiautomator", "dump", "/sdcard/window_dump.xml"], capture_output=True, text=True)
    if d.returncode != 0:
        sys.exit(f"adb failed (set ANDROID_SERIAL when several devices are attached): {d.stderr.strip()}")
    return subprocess.run(["adb", "exec-out", "cat", "/sdcard/window_dump.xml"], capture_output=True, text=True).stdout


def nodes(xml):
    for m in re.finditer(r"<node [^>]*>", xml):
        n = m.group(0)
        attr = lambda k: (re.search(k + r'="([^"]*)"', n) or [None, ""])[1]
        yield attr("text"), attr("content-desc"), attr("bounds")


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("list", "tap"):
        sys.exit(__doc__)
    if sys.argv[1] == "list":
        for text, desc, bounds in nodes(dump()):
            if text or desc:
                print(repr(text), repr(desc), bounds)
        return
    want, idx = sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 0
    hits = [b for t, d, b in nodes(dump()) if want in (t, d)]
    if len(hits) <= idx:
        sys.exit(f"no node #{idx} with text or content-desc {want!r} ({len(hits)} found)")
    x1, y1, x2, y2 = map(int, re.findall(r"\d+", hits[idx]))
    subprocess.run(["adb", "shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2)])
    print("tapped", hits[idx])


main()
