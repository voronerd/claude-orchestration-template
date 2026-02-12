#!/bin/bash
# Dispatcher for SessionStart hooks
# Template-managed - copier updates this file

HOOKS_DIR="$(dirname "$0")"

run_hook() {
    local script="$HOOKS_DIR/$1"
    [[ -x "$script" ]] || return 0
    "$script"
}

run_hook check-onboarding.sh

exit 0
