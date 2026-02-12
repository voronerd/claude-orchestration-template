---
name: run-prompt
description: Execute prompts with integrated teaming checks, agent routing, and post-run integration verification
argument-hint: <prompt-number(s)-or-name> [--parallel|--sequential]
arguments:
  - name: prompts
    description: One or more prompt IDs to run (e.g., P066 or P066,P067,P068)
    required: true
  - name: parallel
    description: Run independent prompts in parallel (future feature)
    required: false
  - name: skip_teaming
    description: Skip teaming checks (use sparingly)
    required: false
  - name: verify_only
    description: Re-run integration verification without executing prompt
    required: false
allowed-tools: [Read, Write, Task, Bash, Glob]
---

<context>
Git status: ! `git status --short`
Recent prompts: ! `ls -t prompts/*.md | head -5`
</context>

<objective>
Execute one or more prompts from `prompts/` as delegated sub-tasks with fresh context. Supports single prompt execution, parallel execution of multiple independent prompts, and sequential execution of dependent prompts. Includes integrated teaming checks for cost-efficient agent selection and post-run integration verification.
</objective>

<input>
The user will specify which prompt(s) to run via $ARGUMENTS, which can be:

**Single prompt:**

- Empty (no arguments): Run the most recently created prompt (default behavior)
- A prompt number (e.g., "001", "5", "42")
- A partial filename (e.g., "user-auth", "dashboard")

**Multiple prompts:**

- Multiple numbers (e.g., "005 006 007")
- With execution flag: "005 006 007 --parallel" or "005 006 007 --sequential"
- If no flag specified with multiple prompts, default to --sequential for safety
</input>

<process>
<step_0_teaming_checks>
If `skip_teaming=true`, log bypass and skip to step_1.

### 1. Read Doctor Recommendations
```bash
cat /tmp/doctor-report-latest.json 2>/dev/null || echo '{"antiPatterns":[]}'
```

Check for active anti-patterns:
- **STUCK_LOOP**: Suggest breaking session before running more prompts
- **EXPENSIVE_ROUTING**: Remind about @local-coder preference
- **SEQUENTIAL_EXECUTION**: Warn if running multiple prompts sequentially

### 2. Prompt Dependency Analysis

For multiple prompts (comma-separated):
1. Read each prompt file from `prompts/`
2. Identify dependencies between prompts
3. Group into:
   - **Independent**: Can run in parallel (future)
   - **Sequential**: Must run in order

Display dependency graph to user before proceeding.

### 3. Agent Routing Check

For each prompt, determine optimal agent:

| Prompt Type | Indicators | Recommended Agent |
|-------------|------------|-------------------|
| Pure coding | "implement", "write", "fix" | @local-coder (FREE) |
| Research | "investigate", "explore", "find" | @lite-general (FREE) |
| Architecture | "design", "plan", >3 files | @local-orchestrator -> @overseer |
| Security | "auth", "credentials", "API keys" | @code-sentinel |

If prompt doesn't specify agent and COST_TIER=free:
- Default to @local-coder or @lite-general
- Only escalate if local model fails

### 4. Session Health Check

Check session metrics:
```bash
# Count recent errors
grep -c "ERROR\|FAILED" /tmp/claude-session.log 2>/dev/null || echo 0
```

If errors > 3:
- Suggest @local-orchestrator to diagnose before proceeding
- Or suggest fresh session start

### 5. Cost Estimate

Before running, estimate cost tier:
- Count prompts
- Identify agent per prompt
- Sum: FREE operations vs PAID operations
- Display to user for approval
</step_0_teaming_checks>

<step_1_parse_arguments>
Parse $ARGUMENTS to extract:
- Prompt numbers/names (all arguments that are not flags)
- Execution strategy flag (--parallel or --sequential)

<examples>
- "005" -> Single prompt: 005
- "005 006 007" -> Multiple prompts: [005, 006, 007], strategy: sequential (default)
- "005 006 007 --parallel" -> Multiple prompts: [005, 006, 007], strategy: parallel
- "005 006 007 --sequential" -> Multiple prompts: [005, 006, 007], strategy: sequential
</examples>
</step_1_parse_arguments>

<step_2_resolve_files>
For each prompt number/name:

- If empty or "last": Find with `!ls -t prompts/*.md | head -1`
- If a number: Find file matching that zero-padded number (e.g., "5" matches "005-*.md", "42" matches "042-*.md")
- If text: Find files containing that string in the filename

<matching_rules>
- If exactly one match found: Use that file
- If multiple matches found: List them and ask user to choose
- If no matches found: Report error and list available prompts
</matching_rules>
</step_2_resolve_files>

<step_3_execute>
<single_prompt>

1. Read the complete contents of the prompt file
2. Delegate as sub-task using Task tool with subagent_type="local-coder" (default for code-focused prompts)
   > **Escalation:** Use `subagent_type="general-purpose"` only if the prompt requires complex multi-file orchestration, web access, or non-code tasks (e.g., infrastructure provisioning, API integrations needing tool-heavy reasoning).
   > **Ollama down?** If local-coder reports Ollama unavailable, inform the user and offer to retry with general-purpose (PAID escalation).
3. Wait for completion
4. Run post-run verification (step_4) BEFORE archiving
5. Archive prompt to `prompts/completed/` with metadata
6. Commit all work:
   - Stage files YOU modified with `git add [file]` (never `git add .`)
   - Determine appropriate commit type based on changes (fix|feat|refactor|style|docs|test|chore)
   - Commit with format: `[type]: [description]` (lowercase, specific, concise)
7. Return results
</single_prompt>

<parallel_execution>

1. Read all prompt files
2. **Spawn all Task tools in a SINGLE MESSAGE** (this is critical for parallel execution):
   <example>
   Use Task tool for prompt 005
   Use Task tool for prompt 006
   Use Task tool for prompt 007
   (All in one message with multiple tool calls)
   </example>
3. Wait for ALL to complete
4. Run post-run verification (step_4) for each prompt
5. Archive all prompts with metadata
6. Commit all work:
   - Stage files YOU modified with `git add [file]` (never `git add .`)
   - Determine appropriate commit type based on changes (fix|feat|refactor|style|docs|test|chore)
   - Commit with format: `[type]: [description]` (lowercase, specific, concise)
7. Return consolidated results
</parallel_execution>

<sequential_execution>

1. Read first prompt file
2. Spawn Task tool for first prompt
3. Wait for completion
4. Run post-run verification (step_4) for first prompt
5. Archive first prompt
6. Read second prompt file
7. Spawn Task tool for second prompt
8. Wait for completion
9. Run post-run verification (step_4) for second prompt
10. Archive second prompt
11. Repeat for remaining prompts
12. Commit all work:
    - Stage files YOU modified with `git add [file]` (never `git add .`)
    - Determine appropriate commit type based on changes (fix|feat|refactor|style|docs|test|chore)
    - Commit with format: `[type]: [description]` (lowercase, specific, concise)
13. Return consolidated results
</sequential_execution>
</step_3_execute>

<step_4_post_run_verification>
After prompt execution completes, verify integration:

### Step 4.1: Detect Infrastructure Prompts

Check if the executed prompt created new infrastructure:
- Look for new files in git diff: `git diff --name-only HEAD~1`
- Check for new directories created
- Look for keywords in prompt: "create package", "new module", "add service"

If NO new files created -> Skip to Step 4.4 (session metrics only).

### Step 4.2: Extract Integration Metadata

Look for integration_targets in prompt metadata:

1. Read the executed prompt file
2. Look for YAML frontmatter or section like:
   ```yaml
   integration:
     targets:
       - path/to/file.py
     test_command: pytest tests/
   ```
3. If not found, look for "Integration" section in prompt body
4. If still not found, infer from file locations:
   - New handler -> check main bot.py
   - New service -> check __init__.py and calling handlers
   - New agent -> check CLAUDE.md

### Step 4.3: Invoke @integration-check

Delegate to the integration-check agent:

```
Use Task tool with subagent_type="integration-check":

created_files: [list files from git diff --name-only that are new]
integration_targets: [list from Step 4.2]
test_command: [from prompt metadata, or "pytest tests/integration/" if exists]
```

**Interpret results:**
- **PASS**: Proceed to commit and archive
- **WARN**: Display warning but allow proceeding (dead imports detected)
- **FAIL**: BLOCK completion and display:
  ```
  INTEGRATION VERIFICATION FAILED

  Created files are not properly integrated:
  [list missing integrations from @integration-check output]

  Required actions:
  1. Add missing imports to target files
  2. Re-run verification: /run-prompt $prompt --verify-only
  ```

### Step 4.4: Session Health Update

After verification (pass or fail):
1. Log result to `/tmp/teaming-decisions.log`
2. Update session metrics
3. If files > 3 created AND PASS: Suggest @overseer architecture review

### Step 4.5: Deployment Check (MANDATORY)

After all prompts complete successfully:

1. **Detect Production-Affecting Changes**
   ```bash
   git diff --name-only HEAD~1 | grep -E "^src/"
   ```

2. **If src/ modified**, ASK USER:
   > "This task modified src/. Deploy to production production-bot (LXC <container-id>)?"

3. **If user approves**, deploy using project-specific deployment scripts:
   ```bash
   # Example deployment (customize for your infrastructure):
   # scp -r app/src $DEPLOY_USER@$DEPLOY_HOST:/tmp/app/
   # ssh $DEPLOY_USER@$DEPLOY_HOST 'cd /app && docker compose up -d --build'
   ./scripts/deploy.sh  # Project-specific deployment script
   ```

4. **Verify deployment**:
   ```bash
   curl -s http://${HEALTH_CHECK_HOST:-localhost}:${HEALTH_CHECK_PORT:-8081}/health
   ./scripts/test-bot.sh "test"  # Project-specific test script
   ```

5. Log deployment to `/tmp/teaming-decisions.log`

**Why this matters:** Without deployment, code changes remain local while production runs stale code, causing user-visible bugs (e.g., LLM hallucinations instead of email data).

### Step 4.6: Update Task Detail File (MANDATORY)

After execution completes, update the associated task detail file:

1. **Find Task Detail File**
   - Extract Task ID from prompt (e.g., "Task ID: FEAT-080" or "FEAT-080" in filename)
   - **Normalize to lowercase** for glob: FEAT-080 -> feat-080
   - Check `tasks/done/` first - if already archived, skip this step
   - Look for matching file in `tasks/detail/` (e.g., `feat-080-*.md`)
   - If no task file found in either location, skip this step (prompt may not have associated task)
   - If multiple matches, use first and log warning

2. **Update Task Detail File**
   - Change `**Status:**` from "Planning" or "In Progress" to "Complete"
   - Find sections by TITLE pattern (not fixed numbers, as templates vary):
     - `## N. Success Metrics` - check off completed items
     - `## N. Verification Checklist` or `## N. Verification` - check off items
     - `## N. Execution Log` - add execution entries:
       ```markdown
       | Date | Phase | Action | Result |
       | YYYY-MM-DD | Execute | @agent-name: Description | PASS/FAIL |
       ```
     - `## N. Completion Criteria` - check off items
   - Add Execution Report subsection under Execution Log with:
     - Prompt file path
     - Execution date
     - Agent teaming table (agent, role, cost, result)
     - Files created/modified
     - Reviewer findings (if any)

3. **Archive Task Detail**
   - Move file from `tasks/detail/` to `tasks/done/`
   - Example: `mv tasks/detail/feat-080-*.md tasks/done/`

4. **Update Pipeline File** (CRITICAL - often missed)
   - Determine pipeline from Task ID prefix: FEAT -> `tasks/pipelines/features.md`, AGT -> `agents.md`, etc.
   - Find the task row in the pipeline file
   - Update status: `**Planning**` -> `**Complete**`
   - Update detail path: `tasks/detail/` -> `tasks/done/`
   - Add commit hash if available

5. **Update Master Dashboard** (if task appears there)
   - Check if task has a summary row in `tasks/master.md`
   - Update status or progress counter (e.g., "Planning" -> "In Progress (1/17)")

**Why this matters:** The task detail file is the canonical record of execution, but the pipeline file is where teams track overall progress. Without updating both, dashboards show stale status and blockers aren't properly unblocked.
</step_4_post_run_verification>
</process>

<context_strategy>
By delegating to a sub-task, the actual implementation work happens in fresh context while the main conversation stays lean for orchestration and iteration.
</context_strategy>

<output>
<single_prompt_output>
[Teaming] Pre-flight checks: PASS
[Teaming] Agent routing: @local-coder (FREE)
[Teaming] Cost estimate: 0 PAID calls

Executed: prompts/005-implement-feature.md
Archived to: prompts/completed/005-implement-feature.md

[Integration] Verification: PASS
[Task Detail] Updated: tasks/done/feat-080-implement-feature.md
[Deployment] src/ not modified - no deployment needed

<results>
[Summary of what the sub-task accomplished]
</results>
</single_prompt_output>

<parallel_output>
[Teaming] Pre-flight checks: PASS
[Teaming] Cost estimate: 0 PAID calls

Executed in PARALLEL:

- prompts/005-implement-auth.md
- prompts/006-implement-api.md
- prompts/007-implement-ui.md

All archived to prompts/completed/

[Integration] Verification: PASS (3 prompts)
[Deployment] src/ modified - user declined deployment

<results>
[Consolidated summary of all sub-task results]
</results>
</parallel_output>

<sequential_output>
[Teaming] Pre-flight checks: PASS
[Teaming] Cost estimate: 0 PAID calls

Executed SEQUENTIALLY:

1. prompts/005-setup-database.md -> Success [Integration: PASS]
2. prompts/006-create-migrations.md -> Success [Integration: PASS]
3. prompts/007-seed-data.md -> Success [Integration: PASS]

All archived to prompts/completed/

[Deployment] src/ modified - deployed to LXC <container-id>

<results>
[Consolidated summary showing progression through each step]
</results>
</sequential_output>
</output>

<critical_notes>

- For parallel execution: ALL Task tool calls MUST be in a single message
- For sequential execution: Wait for each Task to complete before starting next
- Archive prompts only after successful completion AND integration verification
- If any prompt fails, stop sequential execution and report error
- If integration verification fails, BLOCK archiving until fixed
- Provide clear, consolidated results for multiple prompt execution
- Always run post-run verification before archiving/committing
- Always update task detail file (Step 4.6) with execution report before committing
- Task detail file is the canonical audit trail - never skip updating it
</critical_notes>

<bypass>
If `skip_teaming=true`:
- Log bypass to `/tmp/teaming-decisions.log`
- Skip step_0 pre-flight checks
- Still run step_4 post-run verification (cannot be skipped)
</bypass>

<verify_only_mode>
If `verify_only=true`:
- Skip steps 0-3 entirely
- Run only step_4 post-run verification on the specified prompt
- Useful for re-running integration checks after manual fixes
</verify_only_mode>
