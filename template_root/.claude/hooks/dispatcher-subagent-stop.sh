#!/bin/bash
# Dispatcher for SubagentStop hooks
# Runs all subagent-stop hooks (no tool-based routing needed)
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

# SubagentStop always runs both hooks
run_hook log-agent.sh
run_hook log-sentinel-review.sh

exit 0
