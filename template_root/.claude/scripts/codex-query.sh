#!/bin/bash
# Generic wrapper for GPT-5.3-Codex via the Codex CLI
# Finds codex on PATH, falls back to npx if not installed globally.
# Usage: codex-query.sh "PROMPT" or echo "PROMPT" | codex-query.sh

MODEL="${CODEX_MODEL:-gpt-5.3-codex}"

if command -v codex > /dev/null 2>&1; then
    CODEX_CMD=(codex)
else
    CODEX_CMD=(npx --yes @openai/codex)
fi

if [[ -n "$1" ]]; then
    PROMPT="$1"
else
    PROMPT=$(cat)
fi

if [[ -z "$PROMPT" ]]; then
    echo "Usage: $0 \"PROMPT\" or echo \"PROMPT\" | $0"
    exit 1
fi

"${CODEX_CMD[@]}" exec -m "$MODEL" -s read-only "$PROMPT" 2>&1
