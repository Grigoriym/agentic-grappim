#!/bin/bash
# Worker CLI invoked by the /ollama-relay:bulk-read skill (and directly, by hand,
# for manual testing). Delegates a question over one or more files to a local
# Ollama model. Raw file contents are sent to Ollama, never returned to the
# caller — only the model's summary is.
#
# Usage:
#   bulk-read.sh --question "..." --paths file1 [file2 ...]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
source "$SCRIPT_DIR/_generate.sh"

QUESTION=""
PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --question)
      QUESTION="$2"
      shift 2
      ;;
    --paths)
      shift
      while [[ $# -gt 0 && "$1" != --* ]]; do
        PATHS+=("$1")
        shift
      done
      ;;
    *)
      echo "[ollama-relay] Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$QUESTION" ]; then
  echo "[ollama-relay] ERROR: --question is required." >&2
  exit 1
fi
if [ "${#PATHS[@]}" -eq 0 ]; then
  echo "[ollama-relay] ERROR: --paths requires at least one file." >&2
  exit 1
fi
for p in "${PATHS[@]}"; do
  if [ ! -f "$p" ] || [ ! -r "$p" ]; then
    echo "[ollama-relay] ERROR: '$p' does not exist or is not readable." >&2
    exit 1
  fi
done

MODEL="${OLLAMA_RELAY_MODEL:-qwen2.5-coder:14b}"

RESULT="$(_orelay_generate "$MODEL" "$QUESTION" "${PATHS[@]}")"
STATUS=$?
if [ "$STATUS" -ne 0 ]; then
  # _orelay_generate already printed the specific reason to stderr.
  exit 1
fi

RESPONSE="$(jq -r '.response' <<< "$RESULT")"
ELAPSED="$(jq -r '.elapsed_seconds' <<< "$RESULT")"
EST_PROMPT="$(jq -r '.est_prompt_tokens' <<< "$RESULT")"
ACTUAL_PROMPT="$(jq -r '.actual_prompt_tokens' <<< "$RESULT")"
OUTPUT_TOKENS="$(jq -r '.output_tokens' <<< "$RESULT")"
NUM_CTX="$(jq -r '.num_ctx' <<< "$RESULT")"

printf '%s\n' "$RESPONSE"

echo "[ollama-relay] model=${MODEL} elapsed=${ELAPSED}s est_prompt=${EST_PROMPT}tok actual_prompt=${ACTUAL_PROMPT}tok output=${OUTPUT_TOKENS}tok num_ctx=${NUM_CTX}" >&2

DATA_DIR="$(_orelay_data_dir)"
jq -nc \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson files "$(printf '%s\n' "${PATHS[@]}" | jq -R . | jq -s .)" \
  --arg question "$QUESTION" \
  --arg model "$MODEL" \
  --argjson num_ctx "$NUM_CTX" \
  --argjson est_prompt_tokens "$EST_PROMPT" \
  --argjson actual_prompt_tokens "${ACTUAL_PROMPT:-null}" \
  --argjson output_tokens "${OUTPUT_TOKENS:-null}" \
  --argjson elapsed_seconds "$ELAPSED" \
  '{ts:$ts, files:$files, question:$question, model:$model, num_ctx:$num_ctx, est_prompt_tokens:$est_prompt_tokens, actual_prompt_tokens:$actual_prompt_tokens, output_tokens:$output_tokens, elapsed_seconds:$elapsed_seconds}' \
  >> "$DATA_DIR/bulk-read.log" 2>/dev/null || true
