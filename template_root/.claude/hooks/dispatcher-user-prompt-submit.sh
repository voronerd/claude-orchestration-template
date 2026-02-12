#!/bin/bash
# Dispatcher for UserPromptSubmit hooks
# Routes to atomic scripts
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

run_hook route-task.sh

echo "$INPUT"
exit 0
