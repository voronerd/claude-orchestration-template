#!/bin/bash
# Block Bash commands that write code files without agent delegation

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ -z "$COMMAND" ]] && exit 0

# Fix 5: Project-scoped state
STATE_DIR="${CLAUDE_STATE_DIR:-${HOME}/.claude/.state}"
AGENT_LOG="$STATE_DIR/agent-usage.log"

CODE_EXT='sh|bash|py|python|js|javascript|ts|typescript|jsx|tsx|go|rs|rb|pl|php|java|c|cpp|h|hpp|cs'
LEASE_SECONDS=300

# Fix 7: Case-insensitive matching
shopt -s nocasematch

agent_authorized() {
    [[ ! -f "$AGENT_LOG" ]] && return 1
    [[ "$(stat -c %u "$AGENT_LOG" 2>/dev/null)" != "$(id -u)" ]] && return 1
    # Fix 4: Validate content format
    grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}.*AGENT_COMPLETED" "$AGENT_LOG" 2>/dev/null || return 1
    local DIFF=$(($(date +%s) - $(stat -c %Y "$AGENT_LOG" 2>/dev/null)))
    [[ $DIFF -gt $LEASE_SECONDS ]] && return 1
    return 0
}

is_tmp_path() {
    local p="$1"
    [[ "$p" =~ ^/tmp/ ]] && realpath -m "$p" 2>/dev/null | grep -q "^/tmp/"
}

detect_code_write() {
    local cmd="$1"

    # Fix 8: Block touch on lease file
    if [[ "$cmd" =~ touch.*agent-usage\.log ]] || [[ "$cmd" =~ touch.*/\.claude/\.state/ ]]; then
        return 0
    fi

    # Pattern 1: Redirect to code file
    if [[ "$cmd" =~ \>[[:space:]]*[^[:space:]]+\.($CODE_EXT) ]]; then
        is_tmp_path "${BASH_REMATCH[0]}" && return 1
        return 0
    fi

    # Pattern 2-5: heredocs, tee, curl/wget, mv/cp
    [[ "$cmd" =~ \<\<.*EOF && "$cmd" =~ \.($CODE_EXT) && ! "$cmd" =~ /tmp/ ]] && return 0
    [[ "$cmd" =~ tee.*\.($CODE_EXT) && ! "$cmd" =~ /tmp/ ]] && return 0
    [[ "$cmd" =~ (curl.*-o|wget.*-O).*\.($CODE_EXT) && ! "$cmd" =~ /tmp/ ]] && return 0
    [[ "$cmd" =~ (mv|cp)[[:space:]].*\.($CODE_EXT) && ! "$cmd" =~ /tmp/ ]] && return 0

    # Fix 6: Additional write patterns - sed -i, awk, dd, install
    [[ "$cmd" =~ sed[[:space:]]+-i.*\.($CODE_EXT) && ! "$cmd" =~ /tmp/ ]] && return 0
    [[ "$cmd" =~ awk.*\>.*\.($CODE_EXT) && ! "$cmd" =~ /tmp/ ]] && return 0
    [[ "$cmd" =~ dd[[:space:]].*of=.*\.($CODE_EXT) && ! "$cmd" =~ /tmp/ ]] && return 0
    [[ "$cmd" =~ install[[:space:]].*\.($CODE_EXT) && ! "$cmd" =~ /tmp/ ]] && return 0

    # Pattern 7: Interpreter file writes
    if [[ "$cmd" =~ (python3?|node|ruby|perl|php)[[:space:]]+-[ce][[:space:]] ]]; then
        [[ "$cmd" =~ open\( && "$cmd" =~ (\"w\"|\'w\'|\"a\"|\'a\') ]] && return 0
        [[ "$cmd" =~ (writeFile|writeSync|appendFile) ]] && return 0
        [[ "$cmd" =~ (File\.write|File\.open|IO\.write) ]] && return 0
        [[ "$cmd" =~ (file_put_contents|fwrite|fopen) ]] && return 0
    fi

    return 1
}

if detect_code_write "$COMMAND" && ! agent_authorized; then
    echo "BLOCKED: Agent authorization required for code file writes" >&2
    echo "Command: ${COMMAND:0:60}..." >&2
    exit 2
fi

echo "$(date +%Y-%m-%dT%H:%M:%S) CMD: ${COMMAND:0:200}" >> "$STATE_DIR/bash-commands.log" 2>/dev/null
exit 0
