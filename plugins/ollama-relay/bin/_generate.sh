#!/bin/bash
# Shared "call Ollama and measure it" logic. Sourced, never executed directly.
# Used identically by bulk-read.sh and bench.sh so this logic exists exactly once.
#
# Unlike _common.sh (hook logic, must always fail open silently), this file is
# only ever invoked by a script the user or Claude explicitly ran — so it fails
# LOUD (non-zero exit, clear stderr) rather than silently. That's intentional.

_orelay_round_up_1024() {
  local n="$1"
  echo $(( ( (n + 1023) / 1024 ) * 1024 ))
}

# _orelay_generate model question path1 [path2 ...]
# Echoes one JSON object on stdout: {model, response, elapsed_seconds,
# est_prompt_tokens, actual_prompt_tokens, output_tokens, num_ctx}
# Returns non-zero (with an explanatory stderr message) if the request should
# not be sent at all, or if the call itself failed.
_orelay_generate() {
  local model="$1" question="$2"
  shift 2
  local paths=("$@")

  local host temperature num_predict max_ctx
  host="${OLLAMA_RELAY_HOST:-http://localhost:11434}"
  temperature="${OLLAMA_RELAY_TEMPERATURE:-0.15}"
  num_predict="${OLLAMA_RELAY_NUM_PREDICT:-500}"
  max_ctx="${OLLAMA_RELAY_MAX_CTX:-32768}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "[ollama-relay] ABORTED: jq is required but not found on PATH." >&2
    return 1
  fi

  local instructions
  instructions="You are answering a narrow question about the file contents below. Respond with bullets only. No prose, no greeting, no preamble, no markdown code fences unless the question explicitly asks for code. Every bullet must start with the source file name (and line number if visible) it is drawn from. If the files do not contain enough information to answer, say so in one bullet — do not guess or invent names that are not present in the text below."

  local prompt="$instructions"$'\n\n'
  local p
  for p in "${paths[@]}"; do
    if [ ! -f "$p" ] || [ ! -r "$p" ]; then
      echo "[ollama-relay] ABORTED: '$p' is not a readable regular file." >&2
      return 1
    fi
    prompt="${prompt}<file path=\"${p}\">"$'\n'"$(cat "$p")"$'\n'"</file>"$'\n'
  done
  prompt="${prompt}"$'\n'"Question: ${question}"

  local chars est_tokens reserved_output required num_ctx
  chars=$(printf '%s' "$prompt" | wc -c)
  est_tokens=$(( (chars + 3) / 4 ))
  reserved_output=$(( num_predict + 256 ))
  required=$(( (est_tokens + reserved_output) * 12 / 10 ))

  if [ "$required" -gt "$max_ctx" ]; then
    echo "[ollama-relay] ABORTED: estimated prompt (~${est_tokens} tok) + output budget (${reserved_output} tok) with 20% margin = ~${required} tok, exceeds the tested-safe ceiling of ${max_ctx} (OLLAMA_RELAY_MAX_CTX). Ollama silently truncates input past num_ctx instead of erroring, and truncation has been observed to cause outright hallucinated content — refusing to send. Read the file(s) directly, or split into smaller batches: ${paths[*]}" >&2
    return 1
  fi

  num_ctx=$(_orelay_round_up_1024 "$required")
  if [ "$num_ctx" -gt "$max_ctx" ]; then
    num_ctx="$max_ctx"
  fi

  local payload
  payload="$(jq -n \
    --arg model "$model" \
    --arg prompt "$prompt" \
    --argjson num_ctx "$num_ctx" \
    --argjson num_predict "$num_predict" \
    --argjson temperature "$temperature" \
    '{model:$model, prompt:$prompt, stream:false, options:{num_ctx:$num_ctx, num_predict:$num_predict, temperature:$temperature}}')"

  local start end elapsed response_body
  start=$(date +%s.%N)
  response_body="$(curl -sS -m 180 -X POST "${host}/api/generate" -d "$payload" 2>/tmp/ollama-relay-curl-err.$$)"
  local curl_status=$?
  end=$(date +%s.%N)
  elapsed=$(LC_NUMERIC=C awk -v s="$start" -v e="$end" 'BEGIN { printf "%.2f", e - s }')

  if [ "$curl_status" -ne 0 ] || [ -z "$response_body" ]; then
    local curl_err
    curl_err="$(cat /tmp/ollama-relay-curl-err.$$ 2>/dev/null)"
    rm -f /tmp/ollama-relay-curl-err.$$
    echo "[ollama-relay] ABORTED: request to ${host}/api/generate failed (curl exit ${curl_status}). ${curl_err}" >&2
    return 1
  fi
  rm -f /tmp/ollama-relay-curl-err.$$

  local ollama_error
  ollama_error="$(jq -r '.error // empty' <<< "$response_body" 2>/dev/null)"
  if [ -n "$ollama_error" ]; then
    echo "[ollama-relay] ABORTED: Ollama returned an error: ${ollama_error}" >&2
    return 1
  fi

  jq -c \
    --arg model "$model" \
    --argjson elapsed "$elapsed" \
    --argjson est_prompt_tokens "$est_tokens" \
    --argjson num_ctx "$num_ctx" \
    '{
      model: $model,
      response: (.response // ""),
      elapsed_seconds: $elapsed,
      est_prompt_tokens: $est_prompt_tokens,
      actual_prompt_tokens: (.prompt_eval_count // null),
      output_tokens: (.eval_count // null),
      num_ctx: $num_ctx
    }' <<< "$response_body"
}
