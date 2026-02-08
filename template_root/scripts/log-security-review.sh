#!/bin/bash
# Log security review results for tracking code-sentinel audits
# Usage: log-security-review.sh --commit HASH --result PASS|FAIL --reviewer AGENT_NAME

LOG_DIR="$HOME/.claude-project/logs"
LOG_FILE="${LOG_DIR}/code-sentinel-reviews.log"
COMMIT_HASH=""
RESULT=""
REVIEWER=""

# Create log directory with secure permissions if it doesn't exist
if [[ ! -d "$LOG_DIR" ]]; then
    mkdir -p "$LOG_DIR"
    chmod 0700 "$LOG_DIR"
fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --commit) COMMIT_HASH="$2"; shift ;;
        --result) RESULT="$2"; shift ;;
        --reviewer) REVIEWER="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [[ -z "$COMMIT_HASH" ]]; then
    COMMIT_HASH=$(git rev-parse HEAD 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "Failed to get current commit hash."
        exit 1
    fi
fi

# Validate COMMIT_HASH is exactly 40 hex characters
if ! [[ "$COMMIT_HASH" =~ ^[0-9a-fA-F]{40}$ ]]; then
    echo "Invalid commit hash. Must be exactly 40 hex characters."
    exit 1
fi

if [[ -z "$RESULT" || ( "$RESULT" != "PASS" && "$RESULT" != "FAIL" ) ]]; then
    echo "Invalid or missing result. Use PASS or FAIL."
    exit 1
fi

# Validate REVIEWER is alphanumeric/hyphen/underscore only
if [[ -z "$REVIEWER" ]] || ! [[ "$REVIEWER" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Invalid or missing reviewer name. Must be alphanumeric, hyphen, or underscore only."
    exit 1
fi

TIMESTAMP=$(date --iso-8601=seconds)

LOG_ENTRY="${COMMIT_HASH}|${TIMESTAMP}|${RESULT}|${REVIEWER}"

# Escape sed metacharacters in COMMIT_HASH and REVIEWER
ESCAPED_COMMIT_HASH=$(printf '%s\n' "$COMMIT_HASH" | sed 's/[][\.*^$/]/\\&/g')
ESCAPED_REVIEWER=$(printf '%s\n' "$REVIEWER" | sed 's/[][\.*^$/]/\\&/g')

# Use flock for atomic file operations (prevent race conditions)
exec 200>"$LOG_FILE.lock"
flock -x 200

if [[ ! -f "$LOG_FILE" ]]; then
    touch "$LOG_FILE"
    chmod 0600 "$LOG_FILE"
    if [[ $? -ne 0 ]]; then
        echo "Failed to create log file."
        flock -u 200
        exit 1
    fi
fi

# Check for existing entry and replace it (idempotent)
sed -i "/^${ESCAPED_COMMIT_HASH}|.*|${ESCAPED_REVIEWER}$/d" "$LOG_FILE"

echo "$LOG_ENTRY" >> "$LOG_FILE"
if [[ $? -ne 0 ]]; then
    echo "Failed to write to log file."
    flock -u 200
    exit 1
fi

flock -u 200
exit 0
