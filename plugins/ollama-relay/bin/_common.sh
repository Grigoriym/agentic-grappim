#!/bin/bash
# Shared hook decision/logging logic for ollama-relay. Sourced, never executed directly.
#
# Guiding rule for everything in this file: a bug here must never turn into a block.
# Every function that can fail resolves to "allow" on failure.

_orelay_data_dir() {
  local dir="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/ollama-relay-data}"
  mkdir -p "$dir" 2>/dev/null
  printf '%s' "$dir"
}

_orelay_have_jq() {
  command -v jq >/dev/null 2>&1
}

# _orelay_log tool target lines threshold mode decision reason
_orelay_log() {
  _orelay_have_jq || return 0
  local tool="$1" target="$2" lines="$3" threshold="$4" mode="$5" decision="$6" reason="$7"
  local dir
  dir="$(_orelay_data_dir)"
  jq -nc \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg tool "$tool" \
    --arg target "$target" \
    --argjson lines "${lines:-null}" \
    --argjson threshold "${threshold:-null}" \
    --arg mode "$mode" \
    --arg decision "$decision" \
    --arg reason "$reason" \
    '{ts:$ts, tool:$tool, target:$target, lines:$lines, threshold:$threshold, mode:$mode, decision:$decision, reason:$reason}' \
    >> "$dir/hook.log" 2>/dev/null || true
}

_orelay_is_enforced() {
  case "${OLLAMA_RELAY_ENFORCE:-}" in
    1|true|TRUE|True) return 0 ;;
    *) return 1 ;;
  esac
}

_orelay_threshold() {
  printf '%s' "${OLLAMA_RELAY_MIN_LINES:-350}"
}

_orelay_ollama_host() {
  printf '%s' "${OLLAMA_RELAY_HOST:-http://localhost:11434}"
}

# Fast fail-open health check. 2s timeout — this must never be the reason a session hangs.
_orelay_health_ok() {
  curl -sf -m 2 -o /dev/null "$(_orelay_ollama_host)/api/tags" 2>/dev/null
}

# _orelay_line_count path — echoes line count, or -1 if unreadable.
_orelay_line_count() {
  local path="$1"
  if [ ! -f "$path" ] || [ ! -r "$path" ]; then
    printf '%s' "-1"
    return 0
  fi
  wc -l < "$path" 2>/dev/null || printf '%s' "-1"
}

# _orelay_decide_and_act tool path
# Single entry point both hook scripts call once they've already ruled out
# targeted-read / ambiguous-parse cases. Always exits 0. Only emits stdout
# (the deny JSON) in the one case where enforcement is on, Ollama is reachable,
# and the file is genuinely over threshold.
_orelay_decide_and_act() {
  local tool="$1" path="$2"
  local lines threshold mode
  threshold="$(_orelay_threshold)"
  lines="$(_orelay_line_count "$path")"

  if [ "$lines" = "-1" ]; then
    _orelay_log "$tool" "$path" "null" "$threshold" "n/a" "allow" "unreadable, cannot evaluate"
    exit 0
  fi

  if [ "$lines" -le "$threshold" ] 2>/dev/null; then
    _orelay_log "$tool" "$path" "$lines" "$threshold" "n/a" "allow" "under threshold"
    exit 0
  fi

  # Over threshold from here on.
  if ! _orelay_is_enforced; then
    _orelay_log "$tool" "$path" "$lines" "$threshold" "shadow" "would-deny" "over threshold, shadow mode"
    exit 0
  fi

  if ! _orelay_health_ok; then
    _orelay_log "$tool" "$path" "$lines" "$threshold" "enforce" "allow-offline" "Ollama unreachable within 2s, failing open"
    exit 0
  fi

  _orelay_log "$tool" "$path" "$lines" "$threshold" "enforce" "deny" "over threshold, redirected to bulk-read"
  jq -nc \
    --arg path "$path" --arg lines "$lines" --arg threshold "$threshold" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:("\($path) is \($lines) lines (over the \($threshold)-line ollama-relay threshold). Use the /ollama-relay:bulk-read skill to have a local Ollama model read and summarize it instead of loading it directly.")}}'
  exit 0
}
