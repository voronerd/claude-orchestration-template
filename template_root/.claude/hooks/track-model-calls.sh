#!/bin/bash
# PostToolUse hook: Track MCP model calls and append model_call event
# Input JSON: tool_name, tool_input (with model field)

STATE_DIR="${CLAUDE_STATE_DIR:-${HOME}/.claude/.state}"
HOOKS_DIR="${CLAUDE_HOOKS_DIR:-$(dirname "$0")}"
AGENT_STACK="$STATE_DIR/agent_stack.txt"
LOCK_FILE="$AGENT_STACK.lock"

mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

# Read full JSON input
input=$(cat 2>/dev/null)
[ -z "$input" ] && exit 0

# Extract tool_name
tool_name=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null)
[ -z "$tool_name" ] && exit 0

# Determine model based on tool type
model=""
case "$tool_name" in
  mcp__ollama__*)
    # Ollama tools: model is in tool_input.model
    model=$(echo "$input" | jq -r '.tool_input.model // ""' 2>/dev/null)
    [ -n "$model" ] && model="ollama:$model"
    ;;
  mcp__gemini__*)
    # Gemini tools: model param or infer from tool name
    model=$(echo "$input" | jq -r '.tool_input.model // ""' 2>/dev/null)
    if [ -z "$model" ] || [ "$model" = "null" ]; then
      # Default based on tool - brainstorm/deep-research use pro, else flash
      case "$tool_name" in
        *brainstorm*|*deep-research*|*deep_research*) model="pro" ;;
        *) model="flash" ;;
      esac
    fi
    model="gemini:$model"
    ;;
  mcp__openai__*)
    # OpenAI tools: model is in tool_input.model
    model=$(echo "$input" | jq -r '.tool_input.model // ""' 2>/dev/null)
    if [ -z "$model" ] || [ "$model" = "null" ]; then
      model="gpt-4.1"  # Default model
    fi
    model="openai:$model"
    ;;
  mcp__grok__*)
    # Grok tools: model is in tool_input.model
    model=$(echo "$input" | jq -r '.tool_input.model // ""' 2>/dev/null)
    if [ -z "$model" ] || [ "$model" = "null" ]; then
      model="grok-4-0709"
    fi
    model="grok:$model"
    ;;
  *)
    # Not an MCP model tool - skip
    exit 0
    ;;
esac

# Skip if no model identified
[ -z "$model" ] && exit 0

# Get timestamps and session
timestamp=$(date -Iseconds)
session_id="${CLAUDE_SESSION_ID:-unknown}"

# Read current agent from stack (last line = most recent)
agent_id="orchestrator"
agent_type="orchestrator"
if [ -f "$AGENT_STACK" ]; then
  (
    flock -s 200  # Shared lock for reading
    tail -n 1 "$AGENT_STACK" > "$STATE_DIR/.current_agent" 2>/dev/null
  ) 200>"$LOCK_FILE" 2>/dev/null || true

  agent_line=$(cat "$STATE_DIR/.current_agent" 2>/dev/null)
  rm -f "$STATE_DIR/.current_agent" 2>/dev/null

  if [ -n "$agent_line" ]; then
    IFS=':' read -r agent_id agent_type _ <<< "$agent_line"
  fi
fi

# Build event JSON
event=$(printf '{"ts":"%s","hook":"model_call","session_id":"%s","tool_name":"%s","model":"%s","agent_id":"%s","agent_type":"%s"}' \
  "$timestamp" "$session_id" "$tool_name" "$model" "$agent_id" "$agent_type")

# Append to events.jsonl via helper
echo "$event" | "$HOOKS_DIR/append-event.sh" 2>/dev/null || true

exit 0
