---
name: run-plan
description: Execute PLAN.md files with teaming checks, resume support, and post-execution verification
argument-hint: <path-to-PLAN.md>
arguments:
  - name: plan_path
    description: Path to PLAN.md file (e.g., .planning/phases/07/07-01-PLAN.md)
    required: true
allowed-tools: [Read, Write, Task, Bash, Glob]
---

<objective>
Execute PLAN.md files with intelligent segmentation and resume support. Supports full delegation (no checkpoints), segmented delegation (verify-only checkpoints), or main-context execution (decision checkpoints). Can resume interrupted plans using `.progress.json` tracking and optional `whats-next.md` context.
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
Set `plan_dir` to the directory containing the plan file.

### 2. Check Execution Status — Resume Detection
Check for artifacts in `plan_dir` in this priority order:

**a) SUMMARY.md exists → Plan fully completed**
Ask: "Plan already executed. Re-run from scratch? (y/n)"
If no, exit.

**b) .progress.json exists → Plan partially completed (RESUME)**
Read `.progress.json`. It contains:
```json
{
  "plan": "04-01-PLAN.md",
  "started": "2026-02-14T10:00:00Z",
  "tasks_completed": ["Task 1: Create config schema", "Task 2: Add validation"],
  "last_completed": "Task 2: Add validation",
  "status": "interrupted"
}
```
Display to user:
```
Partial progress found: N of M tasks completed.
Last completed: [task name]
Remaining: [list remaining task names]
```
Ask: "Resume from where you left off? (y/resume from scratch/abort)"
If resume: set `resume_mode=true`, store `completed_tasks` list.

**c) whats-next.md exists in plan_dir → Handoff context available**
If `resume_mode=true` AND `${plan_dir}/whats-next.md` exists:
Read it. Extract `<work_remaining>` and `<critical_context>` sections only (skip the rest to save context).
Pass extracted content as `resume_context` to the subagent in step 3.
If `resume_mode=false`: check for whats-next.md in plan_dir anyway. If found, mention it to the user as available context.

**d) Neither exists → Fresh execution**
Proceed normally.
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
### Progress Tracking (ALL strategies)
Instruct every subagent to write/update `${plan_dir}/.progress.json` after each task completes:
```json
{
  "plan": "<plan filename>",
  "started": "<ISO timestamp>",
  "tasks_completed": ["Task 1: ...", "Task 2: ..."],
  "last_completed": "Task 2: ...",
  "status": "in_progress"
}
```
On plan completion, set `"status": "completed"`. On error, set `"status": "error"`.
Include this instruction in every subagent prompt.

### Resume-Aware Task Filtering
If `resume_mode=true`:
- Parse all `<task>` elements from the plan, extract `<name>` values
- Filter out tasks whose names appear in `completed_tasks` (from `.progress.json`)
- Pass only remaining tasks to the subagent
- Include in subagent prompt: "Tasks 1-N are already completed. Resume from Task N+1."
- If `resume_context` exists (from whats-next.md), append: "Context from previous session: ${resume_context}"

### Strategy A: Full Delegation
Spawn `Task(subagent_type="local-coder")`:
- Fresh: "Execute plan at ${plan_path}. Read for context. Execute ALL tasks. After each task, update ${plan_dir}/.progress.json. Create SUMMARY.md. Commit: feat({phase}): [summary]"
- Resume: "Execute plan at ${plan_path}. Tasks already completed: [list]. Resume from [next task]. After each task, update ${plan_dir}/.progress.json. Create SUMMARY.md. Commit: feat({phase}): [summary]"

> **Escalation:** Use `subagent_type="general-purpose"` only if the plan requires complex multi-file orchestration, web access, or non-code tasks (e.g., infrastructure provisioning, API integrations needing tool-heavy reasoning).
> **Ollama down?** If local-coder reports Ollama unavailable, inform the user and offer to retry with general-purpose (PAID escalation).

### Strategy B: Segmented
For each segment between checkpoints:
- Skip segments whose tasks are all in `completed_tasks` (if resuming)
- Spawn subagent for autonomous tasks (include progress tracking instruction)
- Execute checkpoints in main (user interaction)
- Aggregate results, create SUMMARY.md, commit

### Strategy C: Segmented with Decision Points
Spawn sub-agents for each autonomous segment between decision checkpoints.
Skip completed segments when resuming.
Handle decision/action checkpoints in main context (user prompts only).
Never execute task work inline — delegate each segment to a sub-agent, return to main only for decisions.
Create SUMMARY.md, commit.
</step_3_execute>

<step_4_post_verification>
### 1. Detect New Files
`git status --short | grep '^?'` for new files.

### 2. Integration Check
If new .py files: spawn @integration-check with created files.

### 3. Deployment Prompt
If `services/src/` modified: "Deploy to production? (y/n)"

### 4. Clean Up Progress Tracking
If plan completed successfully, delete `${plan_dir}/.progress.json` (SUMMARY.md supersedes it).
If plan had errors, leave `.progress.json` in place for resume.

### 5. Confirm Completion
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
