#!/bin/bash
# PreToolUse hook for Bash. Fail-open contract: any unexpected error, or any
# command shape we can't confidently classify, must allow the command through.
trap 'exit 0' ERR

INPUT="$(cat)"

command -v jq >/dev/null 2>&1 || exit 0

COMMAND="$(jq -r '.tool_input.command // empty' <<< "$INPUT" 2>/dev/null)"
[ -n "$COMMAND" ] || exit 0

# Ambiguity gate: pipelines, chains, and redirections are always treated as
# "targeted enough" and pass through untouched. Never try to reason about them.
if [[ "$COMMAND" =~ [\|\;\&\<\>] ]]; then
  exit 0
fi

# Narrow, conservative match: exactly one of cat/head/tail/less/more, optional
# short flags, exactly one trailing path argument, nothing else. Anything that
# doesn't match this shape is ambiguous and passes through.
if [[ "$COMMAND" =~ ^[[:space:]]*(cat|head|tail|less|more)([[:space:]]+-[A-Za-z0-9]+([[:space:]]+[0-9]+)?)*[[:space:]]+\"?([^\"\'[:space:]]+)\"?[[:space:]]*$ ]]; then
  FILE_PATH="${BASH_REMATCH[4]}"
else
  exit 0
fi

[ -n "$FILE_PATH" ] || exit 0

CWD="$(jq -r '.cwd // empty' <<< "$INPUT" 2>/dev/null)"
if [ -n "$CWD" ] && [ ! -f "$FILE_PATH" ]; then
  RESOLVED="$CWD/$FILE_PATH"
  [ -f "$RESOLVED" ] && FILE_PATH="$RESOLVED"
fi

[ -f "$FILE_PATH" ] || exit 0

source "$(dirname "$0")/_common.sh"
_orelay_decide_and_act "Bash" "$FILE_PATH"
