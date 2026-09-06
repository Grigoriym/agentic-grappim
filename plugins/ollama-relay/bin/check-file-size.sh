#!/bin/bash
# PreToolUse hook for Read. Fail-open contract: any unexpected error here must
# result in the original Read proceeding, never in a block.
trap 'exit 0' ERR

INPUT="$(cat)"

command -v jq >/dev/null 2>&1 || exit 0

# Targeted reads (offset/limit given) always pass through, unconditionally,
# before any shadow/enforce logic even runs.
OFFSET="$(jq -r '.tool_input.offset // empty' <<< "$INPUT" 2>/dev/null)"
LIMIT="$(jq -r '.tool_input.limit // empty' <<< "$INPUT" 2>/dev/null)"
if [ -n "$OFFSET" ] || [ -n "$LIMIT" ]; then
  exit 0
fi

FILE_PATH="$(jq -r '.tool_input.file_path // empty' <<< "$INPUT" 2>/dev/null)"
[ -n "$FILE_PATH" ] || exit 0

source "$(dirname "$0")/_common.sh"
_orelay_decide_and_act "Read" "$FILE_PATH"
