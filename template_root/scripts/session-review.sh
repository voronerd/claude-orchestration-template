#!/usr/bin/env bash
#
# session-review.sh - Parse Claude Code session JSONL for meta-process review
#
# Usage:
#   ./scripts/session-review.sh              # Review most recent session
#   ./scripts/session-review.sh <session-id> # Review specific session by ID prefix
#

set -euo pipefail

# Auto-detect project session directory
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_PATH_ENCODED=$(echo "$PROJECT_ROOT" | tr '/' '-' | sed 's/^-//')
SESSION_DIR="$HOME/.claude/projects/$PROJECT_PATH_ENCODED"
AGENT_USAGE_LOG="$PROJECT_ROOT/.claude/.state/agent-usage.log"

# Find session file based on argument or most recent
find_session_file() {
    local prefix="${1:-}"

    if [[ -n "$prefix" ]]; then
        # Find file matching prefix (not in subagents/)
        find "$SESSION_DIR" -maxdepth 1 -name "${prefix}*.jsonl" -type f 2>/dev/null | head -1
    else
        # Find most recent session file (not in subagents/)
        find "$SESSION_DIR" -maxdepth 1 -name "*.jsonl" -type f -printf '%T@ %p\n' 2>/dev/null | \
            sort -rn | head -1 | cut -d' ' -f2-
    fi
}

# Main parsing function
parse_session() {
    local file="$1"

    # Extract session ID from filename (first 8 chars of UUID)
    local basename
    basename=$(basename "$file" .jsonl)
    local session_id="${basename:0:8}"

    # Declare associative arrays for counting
    declare -A tool_counts
    declare -A agent_counts
    declare -A model_counts
    # Initialize arrays to avoid "unbound variable" with set -u
    tool_counts[_dummy_]=0; unset 'tool_counts[_dummy_]'
    agent_counts[_dummy_]=0; unset 'agent_counts[_dummy_]'
    model_counts[_dummy_]=0; unset 'model_counts[_dummy_]'

    # Track timestamps and errors
    local first_timestamp=""
    local last_timestamp=""
    local errors=()

    # Stream parse the file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Extract timestamp (if present)
        local ts
        ts=$(printf '%s\n' "$line" | jq -r '.timestamp // empty' 2>/dev/null) || continue
        if [[ -n "$ts" ]]; then
            [[ -z "$first_timestamp" ]] && first_timestamp="$ts"
            last_timestamp="$ts"
        fi

        # Check message type
        local msg_type
        msg_type=$(printf '%s\n' "$line" | jq -r '.type // empty' 2>/dev/null) || continue

        if [[ "$msg_type" == "assistant" ]]; then
            # Extract tool names from assistant messages
            # jq outputs one tool name per line for arrays
            while IFS= read -r tool_name; do
                [[ -n "$tool_name" ]] && { tool_counts["$tool_name"]=${tool_counts["$tool_name"]:-0}; ((tool_counts["$tool_name"]++)); } || true
            done < <(printf '%s\n' "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .name' 2>/dev/null)

            # Check for Task tool with subagent_type
            while IFS= read -r subagent; do
                [[ -n "$subagent" ]] && { agent_counts["$subagent"]=${agent_counts["$subagent"]:-0}; ((agent_counts["$subagent"]++)); } || true
            done < <(printf '%s\n' "$line" | jq -r '.message.content[]? | select(.type=="tool_use" and .name=="Task") | .input.subagent_type // empty' 2>/dev/null)

            # Extract model usage from various tool calls
            # Ollama models (local/free): mcp__ollama__ollama_chat and mcp__ollama__ollama_generate
            while IFS= read -r model; do
                if [[ -n "$model" && "$model" != "null" ]]; then
                    local key="ollama:$model"
                    model_counts["$key"]=${model_counts["$key"]:-0}
                    ((model_counts["$key"]++)) || true
                fi
            done < <(printf '%s\n' "$line" | jq -r '.message.content[]? | select(.type=="tool_use" and (.name=="mcp__ollama__ollama_chat" or .name=="mcp__ollama__ollama_generate")) | .input.model // empty' 2>/dev/null)

            # Gemini models (paid): mcp__gemini__* tools
            while IFS= read -r model; do
                # Skip null/empty models (tools like gemini-brainstorm don't have model param)
                if [[ -n "$model" && "$model" != "null" ]]; then
                    local key="gemini:$model"
                    model_counts["$key"]=${model_counts["$key"]:-0}
                    ((model_counts["$key"]++)) || true
                fi
            done < <(printf '%s\n' "$line" | jq -r '.message.content[]? | select(.type=="tool_use" and (.name | startswith("mcp__gemini__"))) | .input.model' 2>/dev/null)

            # Claude subagent models: Task tool with model field
            while IFS= read -r model; do
                if [[ -n "$model" && "$model" != "null" ]]; then
                    local key="claude:$model"
                    model_counts["$key"]=${model_counts["$key"]:-0}
                    ((model_counts["$key"]++)) || true
                fi
            done < <(printf '%s\n' "$line" | jq -r '.message.content[]? | select(.type=="tool_use" and .name=="Task") | .input.model // empty' 2>/dev/null)

        elif [[ "$msg_type" == "user" ]]; then
            # Check for actual tool failures in tool_result content
            # Be selective: only flag real errors, not text that mentions "error"
            local result_content
            result_content=$(printf '%s\n' "$line" | jq -r '.message.content[]? | select(.type=="tool_result") | .content // empty' 2>/dev/null) || continue

            # Pattern 1: Non-zero exit codes (actual command failures)
            if echo "$result_content" | grep -qE 'exit code [1-9]|Exit code: [1-9]|exited with [1-9]'; then
                local err_snippet
                err_snippet=$(echo "$result_content" | grep -E 'exit code [1-9]|Exit code: [1-9]|exited with [1-9]' | head -1 | cut -c1-100)
                [[ -n "$err_snippet" ]] && errors+=("$err_snippet")
            # Pattern 2: Permission/access failures (unambiguous shell errors)
            elif echo "$result_content" | grep -qE 'Permission denied|No such file or directory|command not found'; then
                local err_snippet
                err_snippet=$(echo "$result_content" | grep -E 'Permission denied|No such file or directory|command not found' | head -1 | cut -c1-100)
                [[ -n "$err_snippet" ]] && errors+=("$err_snippet")
            fi
        fi
    done < "$file"

    # Format timestamps for display
    local period_start=""
    local period_end=""
    if [[ -n "$first_timestamp" ]]; then
        period_start=$(date -d "$first_timestamp" +"%Y-%m-%d %H:%M" 2>/dev/null || echo "$first_timestamp")
    fi
    if [[ -n "$last_timestamp" ]]; then
        period_end=$(date -d "$last_timestamp" +"%Y-%m-%d %H:%M" 2>/dev/null || echo "$last_timestamp")
    fi

    # Output the summary
    echo "=== Session Review: $session_id ==="
    echo "Period: ${period_start:-unknown} - ${period_end:-unknown}"
    echo "Project: $(basename "$PROJECT_ROOT")"
    echo ""

    # Tool usage (sorted by count descending)
    echo "TOOL USAGE:"
    if [[ ${#tool_counts[@]} -eq 0 ]]; then
        echo "  (no tools used)"
    else
        for tool in "${!tool_counts[@]}"; do
            printf "  %-12s %d\n" "$tool" "${tool_counts[$tool]}"
        done | sort -k2 -rn
    fi
    echo ""

    # Model usage (sorted by count descending)
    echo "MODEL USAGE:"
    if [[ ${#model_counts[@]} -eq 0 ]]; then
        echo "  (no model calls tracked)"
    else
        for model in "${!model_counts[@]}"; do
            printf "  %-20s %d calls\n" "$model" "${model_counts[$model]}"
        done | sort -k2 -rn
    fi
    echo ""

    # Agent delegations
    echo "AGENT DELEGATIONS (Task tool):"
    if [[ ${#agent_counts[@]} -eq 0 ]]; then
        echo "  (no agent delegations)"
    else
        for agent in "${!agent_counts[@]}"; do
            printf "  %-16s %d calls\n" "$agent" "${agent_counts[$agent]}"
        done | sort -k2 -rn
    fi
    echo ""

    # Agent completions from log file
    echo "AGENT COMPLETIONS (.state/agent-usage.log):"
    if [[ -f "$AGENT_USAGE_LOG" ]]; then
        local completions
        completions=$(cat "$AGENT_USAGE_LOG" 2>/dev/null || true)
        if [[ -n "$completions" ]]; then
            echo "$completions" | while IFS= read -r line; do
                echo "  $line"
            done
        else
            echo "  (no completions logged)"
        fi
    else
        echo "  (log file not found)"
    fi
    echo ""

    # Errors/blocks
    echo "ERRORS/BLOCKS:"
    if [[ ${#errors[@]} -eq 0 ]]; then
        echo "  (none detected)"
    else
        for err in "${errors[@]}"; do
            echo "  $err"
        done | head -10  # Limit to 10 errors
    fi
}

# Main
main() {
    local session_file
    session_file=$(find_session_file "${1:-}")

    if [[ -z "$session_file" || ! -f "$session_file" ]]; then
        echo "Error: No session file found." >&2
        echo "Usage: $0 [session-id-prefix]" >&2
        exit 1
    fi

    parse_session "$session_file"
}

main "$@"
