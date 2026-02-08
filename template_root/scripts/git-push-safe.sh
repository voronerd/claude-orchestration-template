#!/bin/bash
#
# git-push-safe: Wrapper for git push that logs --no-verify bypasses
#
# Usage: ./scripts/git-push-safe.sh [git push arguments]
#
# This wrapper logs any use of --no-verify to $HOME/.claude-project/logs/security-bypass.log
# before executing the actual git push.
#
# To use as default push command, add to your shell config:
#   alias gpush='$HOME/your-project/scripts/git-push-safe.sh'
#
# Or configure git alias:
#   git config --global alias.pushsafe '!$HOME/your-project/scripts/git-push-safe.sh'

LOG_DIR="$HOME/.claude-project/logs"
BYPASS_LOG="${LOG_DIR}/security-bypass.log"

# Create log directory with secure permissions if it doesn't exist
if [[ ! -d "$LOG_DIR" ]]; then
    mkdir -p "$LOG_DIR"
    chmod 0700 "$LOG_DIR"
fi

# Function to sanitize input by replacing pipe and newline characters
# Prevents log injection/parsing attacks
sanitize() {
    printf '%s' "$1" | tr '|' ',' | tr '\n' ' ' | tr '\r' ' '
}

# Check for --no-verify flag
if [[ "$*" == *"--no-verify"* ]]; then
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    USER=$(whoami)
    REMOTE=$(git config --get remote.origin.url 2>/dev/null || echo "unknown")
    BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

    # Sanitize inputs to prevent log injection
    SANITIZED_REMOTE=$(sanitize "$REMOTE")
    SANITIZED_BRANCH=$(sanitize "$BRANCH")
    SANITIZED_ARGS=$(sanitize "$*")

    echo "${TIMESTAMP}|${USER}|${SANITIZED_REMOTE}|${SANITIZED_BRANCH}|BYPASS|args:${SANITIZED_ARGS}" >> "$BYPASS_LOG"

    echo "WARNING: --no-verify bypass logged to $BYPASS_LOG"
fi

# Execute the actual git push
exec git push "$@"
