#!/bin/bash
# usage: run-exec.sh <scenario.md> <outdir> <avd-name> <landscape-rotation-value-for-start>
set -u
AQ=/home/gregory/proj/grappim/agentic-grappim/agent-qa
TMN=/home/gregory/proj/grappim/TaigaMobileNova
P=com.grappim.taigamobile.fdroid.debug
SC=$(realpath "$1"); OUT=$2; AVD=$3; ROT=$4
mkdir -p "$OUT/shots"; cd "$OUT"
export AQ AQ_PACKAGE=$P
[ "$(adb emu avd name | head -1 | tr -d '\r')" = "$AVD" ] || { echo "wrong device"; exit 1; }
# reset: start rotation, network up, fresh launch
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation $ROT
for i in 1 2 3 4; do
  r=$(adb shell "run-as $P sh -c 'nc -z -w 3 10.0.2.2 9000; echo \$?'" | tail -1 | tr -d '\r')
  [ "$r" = 0 ] && break
  adb shell svc wifi disable; sleep 3; adb shell svc wifi enable; sleep 12
done
echo "network=$r"
adb shell am force-stop $P; adb shell am start -n $P/com.grappim.taigamobile.MainActivity >/dev/null; sleep 8
adb logcat -b crash -c
claude -p "Run this scenario. AQ=$AQ (use the literal path in commands). $(cat "$SC")" \
  --model sonnet \
  --append-system-prompt "$(cat $AQ/briefs/executor.md)

## Project notes (docs/EMULATOR_TESTING.md)
$(cat $TMN/docs/EMULATOR_TESTING.md)" \
  --allowedTools "Bash(python3 $AQ/tools/screen.py:*)" "Bash(python3 \$AQ/tools/screen.py:*)" \
     "Bash(python3 $AQ/tools/type.py:*)" "Bash(adb shell input:*)" "Bash(adb shell am start:*)" \
     "Bash(adb shell settings put system user_rotation:*)" "Bash(sleep:*)" "Read" "Write" \
  --permission-mode dontAsk --setting-sources user \
  --json-schema "$(cat $AQ/schemas/steps.json)" --output-format json --max-budget-usd 2 \
  > result.json 2> err.txt
# deterministic check: crash lines from the app's own process
c=$(adb logcat -b crash -d | grep -c "$P")
echo "CHECK no-app-crash: $([ "$c" = 0 ] && echo PASS || echo "FAIL ($c lines)")"
python3 - <<'PY'
import json; d=json.load(open('result.json'))
print({k:d.get(k) for k in ['total_cost_usd','num_turns','duration_ms','is_error','subtype']})
so=d.get('structured_output') or {}
for s in so.get('steps',[]): print(s['index'], s['verdict'], s['screens'], '-', s['observed'][:260])
for f in so.get('findings',[]): print('FINDING', f)
PY
