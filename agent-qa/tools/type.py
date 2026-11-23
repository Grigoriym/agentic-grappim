#!/usr/bin/env python3
"""Type text into the focused field: type.py "<text>"  (tap the field first).

`adb shell input text` goes through the device shell, which splits on spaces and eats
quotes, and `input text` itself turns `%s` into a space. Each word is sent quoted for the
device shell, with spaces as `%s`, so the field gets exactly the given text.
Newlines are sent as KEYCODE_ENTER. ASCII only (`input text` can't type other scripts).
"""
import subprocess
import sys


def send(chunk):
    if not chunk:
        return
    quoted = "'" + chunk.replace("'", "'\\''") + "'"
    subprocess.run(["adb", "shell", "input", "text", quoted.replace(" ", "%s")], check=True)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    text = sys.argv[1]
    if not text.isascii():
        sys.exit("type.py: non-ASCII text can't be typed with adb input text")
    for i, line in enumerate(text.split("\n")):
        if i:
            subprocess.run(["adb", "shell", "input", "keyevent", "KEYCODE_ENTER"], check=True)
        send(line)
    print(f"typed {len(text)} chars")


if __name__ == "__main__":
    main()
