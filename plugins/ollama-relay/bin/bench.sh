#!/bin/bash
# Standalone manual model-comparison tool. Run this by hand from a terminal to
# compare your locally pulled Ollama models on the same real files/question
# before setting OLLAMA_RELAY_MODEL. This script is NEVER invoked by a hook or
# by Claude — it has no allowed-tools entry and is not referenced from any
# SKILL.md. It exists purely for you to eyeball quality/speed side by side.
#
# Usage:
#   bench.sh --question "..." --paths file1 [file2 ...] [--models m1 m2 ...]
# If --models is omitted, every model in `ollama list` is used.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
source "$SCRIPT_DIR/_generate.sh"

QUESTION=""
PATHS=()
MODELS=()

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
    --models)
      shift
      while [[ $# -gt 0 && "$1" != --* ]]; do
        MODELS+=("$1")
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

if [ "${#MODELS[@]}" -eq 0 ]; then
  if ! command -v ollama >/dev/null 2>&1; then
    echo "[ollama-relay] ERROR: 'ollama' not found on PATH, and no --models given." >&2
    exit 1
  fi
  while IFS= read -r line; do
    MODELS+=("$line")
  done < <(ollama list | tail -n +2 | awk '{print $1}')
fi

if [ "${#MODELS[@]}" -eq 0 ]; then
  echo "[ollama-relay] ERROR: no models found (ollama list returned nothing, and no --models given)." >&2
  exit 1
fi

DATA_DIR="$(_orelay_data_dir)"
declare -a SUMMARY_LINES=()

for MODEL in "${MODELS[@]}"; do
  echo "=== ${MODEL} ==="
  RESULT="$(_orelay_generate "$MODEL" "$QUESTION" "${PATHS[@]}")"
  STATUS=$?
  if [ "$STATUS" -ne 0 ]; then
    echo "(failed — see stderr above)"
    echo ""
    continue
  fi

  RESPONSE="$(jq -r '.response' <<< "$RESULT")"
  ELAPSED="$(jq -r '.elapsed_seconds' <<< "$RESULT")"
  EST_PROMPT="$(jq -r '.est_prompt_tokens' <<< "$RESULT")"
  ACTUAL_PROMPT="$(jq -r '.actual_prompt_tokens' <<< "$RESULT")"
  OUTPUT_TOKENS="$(jq -r '.output_tokens' <<< "$RESULT")"
  NUM_CTX="$(jq -r '.num_ctx' <<< "$RESULT")"

  echo "elapsed=${ELAPSED}s  est_prompt=${EST_PROMPT}tok  actual_prompt=${ACTUAL_PROMPT}tok  output=${OUTPUT_TOKENS}tok  num_ctx=${NUM_CTX}"
  printf '%s\n' "$RESPONSE"
  echo ""

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
    >> "$DATA_DIR/bench.log" 2>/dev/null || true

  SUMMARY_LINES+=("${MODEL}|${ELAPSED}|${ACTUAL_PROMPT}|${OUTPUT_TOKENS}")
done

echo "--- Summary (sorted by elapsed) ---"
printf '%-30s %10s %10s %10s\n' "model" "elapsed_s" "prompt_tok" "output_tok"
printf '%s\n' "${SUMMARY_LINES[@]}" | sort -t'|' -k2 -n | while IFS='|' read -r m e p o; do
  printf '%-30s %10s %10s %10s\n' "$m" "$e" "$p" "$o"
done
