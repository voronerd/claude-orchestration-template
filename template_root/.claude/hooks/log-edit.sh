#!/bin/bash
# Log Edit/Write operations with file details
# Receives tool info via stdin from Claude Code

STATE_DIR="${CLAUDE_STATE_DIR:-${HOME}/.claude/.state}"
mkdir -p "$STATE_DIR" 2>/dev/null

INPUT=$(cat 2>/dev/null)
TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)

# Extract file path from input (JSON format - nested under tool_input)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // "unknown"' 2>/dev/null)
TOOL=${TOOL_USE_NAME:-Edit}

echo "$TIMESTAMP $TOOL: $FILE_PATH" >> "$STATE_DIR/session-edits.log" 2>/dev/null

exit 0
