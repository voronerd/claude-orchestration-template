#!/bin/bash
INPUT=$(cat 2>/dev/null)
BLOCK=0
FILE_PATH=$(echo "$INPUT" | jq -r ".tool_input.file_path // .file_path // .path // \"\"" 2>/dev/null)

if [[ "$FILE_PATH" =~ \.claude/hooks/ ]]; then
  echo "[BLOCKED: Cannot modify hook scripts.]" >&2
  exit 2
fi

if echo "$INPUT" | grep -qiE "rm\s+-rf|chmod\s+.*777|eval\s*\("; then
  BLOCK=1
fi
exit $BLOCK
