#!/bin/bash
# usage: run-exec.sh <scenario.md> <outdir>
set -u
AQ=/home/gregory/proj/grappim/agentic-grappim/agent-qa
WM=/home/gregory/proj/grappim/Wallosmobile
SC=$(realpath "$1"); OUT=$2
mkdir -p "$OUT/shots"; cd "$OUT"
export ANDROID_SERIAL=emulator-5554 AQ AQ_PACKAGE=com.grappim.wallosmobile.debug
[ "$(adb emu avd name | head -1 | tr -d '\r')" = Pixel_10a ] || { echo "wrong device"; exit 1; }
adb logcat -b crash -c
claude -p "Run this scenario. AQ=$AQ (use the literal path in commands). $(cat "$SC")" \
  --model sonnet \
  --append-system-prompt "$(cat $AQ/briefs/executor.md)

## Project notes (docs/EMULATOR_TESTING.md)
$(cat $WM/docs/EMULATOR_TESTING.md)" \
  --allowedTools "Bash(python3 $AQ/tools/screen.py:*)" "Bash(python3 \$AQ/tools/screen.py:*)" \
     "Bash(python3 $AQ/tools/type.py:*)" "Bash(python3 \$AQ/tools/type.py:*)" \
     "Bash(adb shell input:*)" "Bash(adb shell am start:*)" "Bash(adb shell am kill:*)" \
     "Bash(adb shell am force-stop com.grappim.wallosmobile.debug)" "Bash(sleep:*)" "Read" "Write" \
  --permission-mode dontAsk --setting-sources user \
  --json-schema "$(cat $AQ/schemas/steps.json)" --output-format json --max-budget-usd 2 \
  > result.json 2> err.txt
python3 - <<'PY'
import json; d=json.load(open('result.json'))
print({k:d.get(k) for k in ['total_cost_usd','num_turns','duration_ms','is_error','subtype']})
so=d.get('structured_output') or {}
for s in so.get('steps',[]): print(s['index'], s['verdict'], s['screens'], '-', s['observed'][:200])
for f in so.get('findings',[]): print('FINDING', f)
PY
