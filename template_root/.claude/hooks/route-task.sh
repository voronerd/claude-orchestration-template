#!/bin/bash
# Route task based on user prompt content
# Injects <system_instruction> directives for agent delegation
# Uses cumulative logic - all matching directives are output
# Now includes Learning Lite suggestions based on historical routing success

STATE_DIR="${CLAUDE_STATE_DIR:-${HOME}/.claude/.state}"

INPUT=$(cat 2>/dev/null)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)

# Skip empty or very short prompts
[ ${#PROMPT} -lt 10 ] && exit 0

DIRECTIVES=""

# Learning Lite: Check if we have a confident suggestion from history
LEARNING_HINT=$("$STATE_DIR/routing-hint.sh" "$PROMPT" 2>/dev/null)
if [ -n "$LEARNING_HINT" ]; then
  DIRECTIVES="${DIRECTIVES}
- LEARNING_LITE: $LEARNING_HINT"
fi

# Security-sensitive tasks
if echo "$PROMPT" | grep -qiE "security|vulnerability|credential|password|auth|secret|api.?key|token"; then
  DIRECTIVES="${DIRECTIVES}
- SECURITY: You MUST delegate to @code-sentinel for security review before any changes."
fi

# Architecture/complex tasks
if echo "$PROMPT" | grep -qiE "architect|design|refactor|complex|integration|migration"; then
  DIRECTIVES="${DIRECTIVES}
- ARCHITECTURE: You MUST delegate to @local-orchestrator for routing (FREE on ${GPU_HOST})."
fi

# Code generation tasks
if echo "$PROMPT" | grep -qiE "implement|create|build|write.*code|new.*feature|add.*function"; then
  DIRECTIVES="${DIRECTIVES}
- CODE: You MUST delegate to @local-coder for code drafting (FREE on ${GPU_HOST})."
fi

# Stuck/debugging tasks
if echo "$PROMPT" | grep -qiE "stuck|error|fail|doesn.t work|broken|debug|not working"; then
  DIRECTIVES="${DIRECTIVES}
- DEBUGGING: You MUST delegate to @local-orchestrator first (FREE), then @gemini-overseer only if still stuck."
fi


# Git operations (commit, PR, branch)
if echo "$PROMPT" | grep -qiE "commit|pull.?request|\bPR\b|branch|git"; then
  DIRECTIVES="${DIRECTIVES}
- GIT: You MUST delegate to @local-git for commit messages, PR summaries, branch names (FREE on ${GPU_HOST})."
fi

# Research/exploration tasks (general keywords)
if echo "$PROMPT" | grep -qiE "research|explore|investigate|brainstorm|option|compare|which.*should"; then
  DIRECTIVES="${DIRECTIVES}
- RESEARCH: You MUST delegate to @gemini-overseer with gemini-brainstorm (PAID - use sparingly)."
fi

# Plugin /research:* commands - enforce cost-conscious routing
if echo "$PROMPT" | grep -qE "^/research:" ; then
  DIRECTIVES="${DIRECTIVES}
- RESEARCH_COMMAND: /research:* command detected. Cost Protocol: Try @local-orchestrator FIRST (FREE Ollama). Only escalate to Gemini if local cannot provide adequate research depth."
fi

# ALWAYS output base instruction (unconditional subagent preference)
# Pattern-specific directives are added when detected
cat << XMLEOF
<system_instruction>
ROLE: You are the Lead Engineer (Orchestrator).
CONSTRAINT: You are FORBIDDEN from editing code files directly.
REQUIRED: You MUST delegate coding tasks to specialized agents.
WORKFLOW: 1) Analyze request 2) Delegate to appropriate agent 3) Review output before presenting to user

DEFAULT BEHAVIOR: Use subagents wherever possible. Prefer Task tool with appropriate subagent_type over direct tool usage. Only use tools directly for trivial operations (reading files, listing directories).
$([ -n "$DIRECTIVES" ] && echo "
DETECTED TASK TYPES:${DIRECTIVES}")
</system_instruction>
XMLEOF

exit 0
