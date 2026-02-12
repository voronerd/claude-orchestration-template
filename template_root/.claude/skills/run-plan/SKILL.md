---
name: run-plan
description: Execute PLAN.md files with teaming checks and post-execution verification
argument-hint: <path-to-PLAN.md>
arguments:
  - name: plan_path
    description: Path to PLAN.md file (e.g., .planning/phases/07/07-01-PLAN.md)
    required: true
allowed-tools: [Read, Write, Task, Bash, Glob]
---

<objective>
Execute PLAN.md files with intelligent segmentation. Supports full delegation (no checkpoints), segmented delegation (verify-only checkpoints), or main-context execution (decision checkpoints).
</objective>

<input>
plan_path: Path to PLAN.md file to execute (e.g., .planning/phases/07/07-01-PLAN.md)
</input>

<process>
<step_0_teaming_checks>
### 1. Load Teaming Reference
Read `.claude/skills/create-prompt/references/teaming-middleware.md` for helpers.

### 2. Doctor Check
Read `/tmp/doctor-report-latest.json`. Warn on HIGH/CRITICAL patterns but proceed.

### 3. Cost Tier
COST_TIER=${COST_TIER:-free}. Log to `/tmp/teaming-decisions.log`:
`[$(date -Iseconds)] [run-plan] [START] tier=$COST_TIER plan=${plan_path}`
</step_0_teaming_checks>

<step_1_parse_and_validate>
### 1. Read Plan
Read file at `${plan_path}`. If not found, error and exit.

### 2. Check Execution Status
Check if `SUMMARY.md` exists in same directory as plan.
If exists: "Plan already executed. Re-run? (y/n)"
</step_1_parse_and_validate>

<step_2_determine_strategy>
### 1. Count Checkpoints
`grep -c 'type="checkpoint' ${plan_path}` (0 = no checkpoints)

### 2. Classify Strategy
- **A (Fully Autonomous)**: 0 checkpoints -> delegate entire plan
- **B (Segmented)**: only `checkpoint:human-verify` -> delegate segments
- **C (Decision-Dependent)**: has `checkpoint:decision` or `checkpoint:human-action` -> main context

### 3. Log Strategy
Log: `[run-plan] [STRATEGY] selected=${strategy} checkpoints=${count}`
</step_2_determine_strategy>

<step_3_execute>
### Strategy A: Full Delegation
Spawn `Task(subagent_type="local-coder")`:
"Execute plan at ${plan_path}. Read for context. Execute ALL tasks. Create SUMMARY.md. Commit: feat({phase}): [summary]"

> **Escalation:** Use `subagent_type="general-purpose"` only if the plan requires complex multi-file orchestration, web access, or non-code tasks (e.g., infrastructure provisioning, API integrations needing tool-heavy reasoning).
> **Ollama down?** If local-coder reports Ollama unavailable, inform the user and offer to retry with general-purpose (PAID escalation).

### Strategy B: Segmented
For each segment between checkpoints:
- Spawn subagent for autonomous tasks
- Execute checkpoints in main (user interaction)
- Aggregate results, create SUMMARY.md, commit

### Strategy C: Main Context
Execute all tasks sequentially in main context.
Handle decision/action checkpoints with user prompts.
Create SUMMARY.md, commit.
</step_3_execute>

<step_4_post_verification>
### 1. Detect New Files
`git status --short | grep '^?'` for new files.

### 2. Integration Check
If new .py files: spawn @integration-check with created files.

### 3. Deployment Prompt
If `services/src/` modified: "Deploy to production? (y/n)"

### 4. Confirm Completion
Verify SUMMARY.md created and commit made. Report status.
</step_4_post_verification>

<post_completion_menu>
After plan execution completes successfully, present:

**Plan execution complete!**

What's next?

1. **Create prompt for follow-up work** — If the plan revealed additional tasks
2. **Run another plan** — Execute the next phase if one exists
3. **Review results** — Examine outputs before moving on
4. **Done** — No further action needed

If user chooses #1, invoke `/create-prompt` with context from the completed plan.
If user chooses #2, invoke `/run-plan` with the next phase path.
</post_completion_menu>
</process>
