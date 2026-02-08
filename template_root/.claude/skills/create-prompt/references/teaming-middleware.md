# Teaming Middleware Reference
teaming_version: 1.0
last_updated: 2026-02-04

<teaming_middleware version="1.0">

<doctor_check>
## Doctor Check Helper
Read doctor recommendations and warn on session health issues.

```bash
# Read with fallback for missing/corrupt file
DOCTOR_JSON=$(cat /tmp/doctor-report-latest.json 2>/dev/null) || DOCTOR_JSON='{"antiPatterns":[]}'
echo "$DOCTOR_JSON" | jq . >/dev/null 2>&1 || DOCTOR_JSON='{"antiPatterns":[]}'

# Check for HIGH/CRITICAL patterns (warn only, don't block)
HIGH_PATTERNS=$(echo "$DOCTOR_JSON" | jq -r '.antiPatterns[] | select(.severity == "HIGH" or .severity == "CRITICAL") | "\(.name) (\(.severity)): \(.description)"' 2>/dev/null)
[ -n "$HIGH_PATTERNS" ] && echo "[TEAMING WARNING] Active anti-patterns: $HIGH_PATTERNS"
```

**Rules:** Missing file = empty antiPatterns. Corrupt JSON = empty antiPatterns. HIGH/CRITICAL = warn but proceed.
</doctor_check>

<cost_tier_check>
## Cost Tier Helper
Route agents based on cost preference: `COST_TIER=${COST_TIER:-free}`

**COST_TIER=free routing:**
| Task Type | Agent |
|-----------|-------|
| routing | @local-orchestrator |
| code | @local-coder |
| simple | @lite-general |
| review | @local-orchestrator (try first) |

**COST_TIER=paid routing:** @overseer for review, @code-sentinel for security

**Complexity Override (escalate even when free):**
1. Task touches >5 files
2. Security-sensitive code (auth, credentials)
3. Local agent fails 2+ times
4. User explicitly requests paid review

```bash
COST_TIER=${COST_TIER:-free}
FILE_COUNT=${FILE_COUNT:-1}
# Override: escalate if FILE_COUNT > 5 or security-sensitive
[ "$FILE_COUNT" -gt 5 ] && echo "[TEAMING] Complexity override active"
```
</cost_tier_check>

<integration_checkpoint>
## Integration Checkpoint Template
Prevent orphaned infrastructure by requiring explicit integration targets.

**When to use:** New directories, packages, modules, integrations, adapters.

**Question to ask:**
> This is an infrastructure prompt. Which file(s) will import/wire this new code?
> (Prevents orphaned code that passes tests but isn't integrated)

**Store answer as:**
```yaml
integration_targets:
  - file: "src/main.py"
    action: "imports new_handler"
```

**Add to generated prompts:**
```xml
<integration_reminder>
Integration target(s): {targets}
After implementation, verify imports in above file(s). Run @integration-check.
</integration_reminder>
```

| Infrastructure Type | Typical Integration Point |
|---------------------|---------------------------|
| handler/skill | handlers/__init__.py, router |
| agent | .claude/agents/ + CLAUDE.md |
| MCP server | mcp config, entrypoint |
| utility module | package __init__.py |
</integration_checkpoint>

<verification_helper>
## Basic Verification Helper
Post-execution checks to confirm success.

```bash
# File existence check
for f in "$@"; do [ -f "$f" ] || echo "[MISSING] $f"; done

# Syntax validation
python -m py_compile "$file" 2>&1           # Python
python -c "import yaml; yaml.safe_load(open('$file'))"  # YAML
jq . "$file" >/dev/null 2>&1                # JSON

# Integration check
verify_integration() {
  grep -q "$3" "$2" 2>/dev/null && echo "[OK] $1 wired in $2" || echo "[WARN] $1 may be orphaned"
}
# Usage: verify_integration "new_file.py" "main.py" "import new_file"
```

**Checklist:** Files exist, syntax valid, integration points wired, no log errors.
</verification_helper>

<teaming_logger>
## Teaming Logging Helper
Audit trail to `/tmp/teaming-decisions.log`

**Format:** `[TIMESTAMP] [SKILL] [TYPE] tier=TIER agent=AGENT reason=REASON`

```bash
log_teaming() {
  echo "[$(date -Iseconds)] [$1] [$2] tier=${COST_TIER:-free} agent=$3 reason=\"$4\"" >> /tmp/teaming-decisions.log
}
# Usage: log_teaming "create-prompt" "ROUTE" "@local-coder" "standard_code_task"
```

**Decision types:** ROUTE, ESCALATE, SKIP, CHECKPOINT

**Query examples:**
```bash
grep "ESCALATE" /tmp/teaming-decisions.log    # Escalations
grep "\[create-prompt\]" /tmp/teaming-decisions.log  # By skill
grep "tier=paid" /tmp/teaming-decisions.log | wc -l  # Paid count
```
</teaming_logger>

</teaming_middleware>

---
## Quick Reference: Teaming Levels

| Level | Skills | Include |
|-------|--------|---------|
| Full | create-mcp-servers, create-meta-prompts | All 5 sections |
| Standard | create-subagents, create-hooks, create-plans, etc. | Doctor + cost + verify + log |
| Minimal | debug-like-expert, test-bot | Doctor (log only) + log |
