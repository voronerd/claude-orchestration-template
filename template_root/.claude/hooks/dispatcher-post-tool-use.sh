#!/bin/bash
# Dispatcher for PostToolUse hooks
# Routes to atomic scripts based on tool_name
# Template-managed - copier updates this file

HOOKS_DIR="$(dirname "$0")"

# Capture stdin
INPUT=$(cat)

run_hook() {
    local script="$HOOKS_DIR/$1"
    [[ -x "$script" ]] || return 0
    local OUTPUT
    OUTPUT=$(echo "$INPUT" | "$script")
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo "$OUTPUT"
        exit $exit_code
    fi
}

# Extract tool name
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

case "$TOOL_NAME" in
    Edit|Write)
        run_hook log-edit.sh
        ;;
    mcp__ollama__*|mcp__gemini__*|mcp__openai__*|mcp__grok__*)
        run_hook track-model-calls.sh
        ;;
esac

exit 0
