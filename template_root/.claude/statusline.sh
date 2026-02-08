#!/bin/bash
# Claude Code Status Line - Context awareness for proactive handoffs
# Format: Model ● XX% | $X.XX mm:ss/mm:ss +N/-N
#         ^ctx%    ^cost ^total/api   ^churn
#
# Color thresholds:
#   Green  < 60%  - Plenty of room
#   Yellow < 80%  - Start thinking about handoff
#   Red    >= 80% - Prepare handoff NOW

input=$(cat)

# Helper: ms to mm:ss
ms_to_mmss() {
    local ms=$1
    local secs=$((ms / 1000))
    printf "%d:%02d" $((secs / 60)) $((secs % 60))
}

# Extract model
MODEL=$(echo "$input" | jq -r '.model.display_name // .model // "?"')

# Context percentage
PERCENT=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -z "$PERCENT" ]; then
    TOTAL=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
    USED=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
    if [ "$TOTAL" -gt 0 ] 2>/dev/null; then
        PERCENT=$(echo "scale=1; $USED * 100 / $TOTAL" | bc 2>/dev/null || echo "0")
    else
        PERCENT="0"
    fi
fi
PERCENT_INT=$(printf "%.0f" "$PERCENT" 2>/dev/null || echo "0")

# Cost (truncated to 2 decimal places)
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // .cost // 0')
if [ -n "$COST" ] && [ "$COST" != "null" ] && [ "$COST" != "0" ]; then
    COST_DISPLAY=$(printf "%.2f" "$COST" 2>/dev/null || echo "$COST")
    COST_DISPLAY="\$${COST_DISPLAY}"
else
    COST_DISPLAY=""
fi

# Duration: total/api in mm:ss
TOTAL_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
API_MS=$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0')
if [ "$TOTAL_MS" -gt 0 ] 2>/dev/null; then
    DURATION_DISPLAY="$(ms_to_mmss $TOTAL_MS)/$(ms_to_mmss $API_MS)"
else
    DURATION_DISPLAY=""
fi

# Churn: +added/-removed
ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
if [ "$ADDED" -gt 0 ] 2>/dev/null || [ "$REMOVED" -gt 0 ] 2>/dev/null; then
    CHURN_DISPLAY="+${ADDED}/-${REMOVED}"
else
    CHURN_DISPLAY=""
fi

# Colors
RED="\033[0;31m"
YELLOW="\033[0;33m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
DIM="\033[2m"
RESET="\033[0m"

# Context color
if [ "$PERCENT_INT" -ge 80 ] 2>/dev/null; then
    COLOR="$RED"; INDICATOR="!"
elif [ "$PERCENT_INT" -ge 60 ] 2>/dev/null; then
    COLOR="$YELLOW"; INDICATOR="*"
else
    COLOR="$GREEN"; INDICATOR=""
fi

# Build output - only show non-empty segments
OUT="${CYAN}${MODEL}${RESET} ${COLOR}${INDICATOR}${PERCENT_INT}%${RESET}"
[ -n "$COST_DISPLAY" ] && OUT="$OUT ${DIM}${COST_DISPLAY}${RESET}"
[ -n "$DURATION_DISPLAY" ] && OUT="$OUT ${DIM}${DURATION_DISPLAY}${RESET}"
[ -n "$CHURN_DISPLAY" ] && OUT="$OUT ${DIM}${CHURN_DISPLAY}${RESET}"

echo -e "$OUT"
