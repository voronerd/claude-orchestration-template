#!/bin/bash
# Dispatcher for PreToolUse hooks
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
    INPUT="$OUTPUT"
}

# Extract tool name
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

case "$TOOL_NAME" in
    Edit|Write)
        run_hook security-gate.sh
        run_hook enforce-delegation.sh
        ;;
    Bash)
        run_hook security-gate.sh
        run_hook enforce-delegation-bash.sh
        ;;
    Task)
        run_hook inject-ollama-reminder.sh
        run_hook block-local-coder-model.sh
        ;;
    TaskCreate)
        run_hook enforce-skill-usage.sh
        ;;
    *)
        run_hook security-gate.sh
        ;;
esac

echo "$INPUT"
exit 0
