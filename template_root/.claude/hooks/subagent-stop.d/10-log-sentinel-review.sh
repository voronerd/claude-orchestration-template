#!/bin/bash
# SubagentStop hook: Auto-log security reviews after code-sentinel completes
# Input JSON: agent_type, agent_id, result fields
# Outputs nothing on success (hook protocol)

set -euo pipefail
export PATH="/usr/bin:/bin:/usr/local/bin"

# Read full JSON input from stdin
read -r json_input || exit 0
[ -z "$json_input" ] && exit 0

# Extract agent type (try both field names)
subagent_type=$(echo "$json_input" | jq -r '.subagent_type // .agent_type // ""' 2>/dev/null)

# Only process code-sentinel reviews
[ "$subagent_type" != "code-sentinel" ] && exit 0

# Extract result text
result_text=$(echo "$json_input" | jq -r '.result // ""' 2>/dev/null)

# Determine PASS/FAIL based on EXACT success indicators only
# SECURITY: No prefix/partial matching - exact strings only
result_upper=$(echo "$result_text" | tr '[:lower:]' '[:upper:]')

# Check for explicit PASS indicators (EXACT MATCH ONLY)
if [[ "$result_upper" == "PASSED" ]] || \
   [[ "$result_upper" == "PASS" ]] || \
   [[ "$result_upper" == "NO VULNERABILITIES FOUND" ]] || \
   [[ "$result_upper" == "NO VULNERABILITIES" ]] || \
   [[ "$result_upper" == "NO ISSUES FOUND" ]] || \
   [[ "$result_upper" == "CLEAN" ]]; then
    review_result="PASS"
else
    # Default to FAIL - safer to require explicit pass
    review_result="FAIL"
fi

# Call the logging script (suppress output to maintain hook protocol)
# Use git to find repo root for template portability
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
"$REPO_ROOT/scripts/log-security-review.sh" \
    --result "$review_result" \
    --reviewer code-sentinel >/dev/null 2>&1

exit 0
