#!/bin/bash
# SubagentStop hook: Pop from agent stack and append agent_stop event
# Also records routing to Learning Lite history
# Input JSON: agent_id

STATE_DIR="${CLAUDE_STATE_DIR:-${HOME}/.claude/.state}"
HOOKS_DIR="${CLAUDE_HOOKS_DIR:-$(dirname "$0")}"
AGENT_STACK="$STATE_DIR/agent_stack.txt"
LEGACY_LOG="$STATE_DIR/agent-usage.log"
LOCK_FILE="$AGENT_STACK.lock"
PROMPTS_DIR="$STATE_DIR/agent_prompts"

mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

# Read full JSON input
input=$(cat 2>/dev/null)
[ -z "$input" ] && exit 0

# Extract agent_id
agent_id=$(echo "$input" | jq -r '.agent_id // ""' 2>/dev/null)
[ -z "$agent_id" ] && exit 0

# Get current timestamp
timestamp=$(date -Iseconds)
unix_timestamp=$(date +%s)
session_id="${CLAUDE_SESSION_ID:-unknown}"

# Find and remove agent from stack (atomic)
line=""
if [ -f "$AGENT_STACK" ]; then
  (
    flock -x 200
    line=$(grep "^${agent_id}:" "$AGENT_STACK" 2>/dev/null | head -1)
    if [ -n "$line" ]; then
      grep -v "^${agent_id}:" "$AGENT_STACK" > "$AGENT_STACK.tmp" 2>/dev/null
      mv "$AGENT_STACK.tmp" "$AGENT_STACK" 2>/dev/null || rm -f "$AGENT_STACK.tmp"
    fi
    echo "$line" > "$STATE_DIR/.agent_pop_$agent_id" 2>/dev/null
  ) 200>"$LOCK_FILE" 2>/dev/null || exit 0

  line=$(cat "$STATE_DIR/.agent_pop_$agent_id" 2>/dev/null)
  rm -f "$STATE_DIR/.agent_pop_$agent_id" 2>/dev/null
fi

[ -z "$line" ] && exit 0

# Parse line: agent_id:agent_type:start_timestamp
IFS=':' read -r _ agent_type start_ts <<< "$line"

# Calculate duration in milliseconds
duration_ms=0
if [ -n "$start_ts" ] && [ "$start_ts" -gt 0 ] 2>/dev/null; then
  duration_ms=$(( (unix_timestamp - start_ts) * 1000 ))
fi

# Build event JSON
event=$(printf '{"ts":"%s","hook":"agent_stop","session_id":"%s","agent_id":"%s","agent_type":"%s","duration_ms":%d}' \
  "$timestamp" "$session_id" "$agent_id" "$agent_type" "$duration_ms")

# Append to events.jsonl via helper
echo "$event" | "$HOOKS_DIR/append-event.sh" 2>/dev/null || true

# Legacy log for backward compatibility
echo "$timestamp AGENT_COMPLETED: $agent_id ($agent_type) duration=${duration_ms}ms" >> "$LEGACY_LOG" 2>/dev/null || true

# Learning Lite: Record routing decision if we have the prompt
prompt_file="$PROMPTS_DIR/${agent_id}.prompt"
if [ -f "$prompt_file" ]; then
  prompt=$(cat "$prompt_file" 2>/dev/null)
  rm -f "$prompt_file" 2>/dev/null
  
  # Determine cost tier based on agent type
  cost_tier="free"
  case "$agent_type" in
    code-sentinel|overseer|gemini-overseer|openai-overseer)
      cost_tier="paid"
      ;;
  esac
  
  # Record routing (assume success=1 since agent completed without error)
  # Background process to not block hook
  (
    python3 "$STATE_DIR/memory.py" record-routing \
      --prompt "$prompt" \
      --agent "$agent_type" \
      --success 1 \
      --duration "$duration_ms" \
      --cost-tier "$cost_tier" \
      --method "static" 2>/dev/null
  ) &
fi

# Log rotation: compress events.jsonl if > 10MB (1% chance check)
if [ $((RANDOM % 100)) -eq 0 ] && [ -f "$STATE_DIR/events.jsonl" ]; then
  size=$(stat -f%z "$STATE_DIR/events.jsonl" 2>/dev/null || stat -c%s "$STATE_DIR/events.jsonl" 2>/dev/null || echo 0)
  if [ "$size" -gt 10485760 ]; then
    date_suffix=$(date +%Y%m%d_%H%M%S)
    gzip -c "$STATE_DIR/events.jsonl" > "$STATE_DIR/events.jsonl.$date_suffix.gz" 2>/dev/null && \
    : > "$STATE_DIR/events.jsonl"
  fi
fi

exit 0
