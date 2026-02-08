---
description: Create a new task with detail file and pipeline entry
argument-hint: <task-name> [--section <section>] [--priority <P0|P1|P2>]
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# Create Task

## Context

- Current timestamp: !`date "+%Y-%m-%d"`
- Task template: `tasks/templates/task_spec.md`
- Pipeline files: `tasks/pipelines/*.md`

## Pipeline Mapping

| Section | Pipeline File | Prefix | Detail Directory |
|---------|---------------|--------|------------------|
| features | `tasks/pipelines/features.md` | `FEAT-` | `tasks/detail/` |
| infrastructure | `tasks/pipelines/infrastructure.md` | `INF-` | `tasks/detail/` |
| security | `tasks/pipelines/security.md` | `SEC-` | `tasks/detail/` |
| agents | `tasks/pipelines/agents.md` | `AGT-` | `tasks/detail/` |

## Instructions

### Step 1: Parse Arguments and Gather Requirements

**Parse $ARGUMENTS:**
```
$ARGUMENTS format: <task-name> [--section <section>] [--priority <P0|P1|P2>]

Examples:
  "email-reply-skill"                        → name only, will prompt for section
  "email-reply-skill --section features"     → name + section
  "fix-auth-bug --section security --priority P0"  → all specified
```

Extract:
- **Task name**: First word/phrase before any `--` flags (e.g., "email-service-refactor")
- **Section**: Value after `--section` flag (if present)
- **Priority**: Value after `--priority` flag (default: P1 if not specified)

If $ARGUMENTS is empty or task name is unclear, use AskUserQuestion to gather:
1. What is the task? (brief description)
2. Which section? Options:
   - "features" - Product capabilities (user-facing functionality)
   - "infrastructure" - Ops and deployment (LXC, proxmox, network, TLS)
   - "security" - Security hardening, pen testing, guardrails
   - "agents" - Claude Code agent infrastructure, cost optimization

### Step 1.5: Duplicate Detection

Before creating the task, check for potential duplicates:

1. **Exact slug match:**
   Use Glob to check if `tasks/detail/*-{task-slug}.md` already exists.
   If match found, warn user with existing file path.

2. **Keyword overlap check:**
   - Extract keywords from task name (split on hyphens/spaces)
   - Remove stop words: "the", "a", "an", "fix", "update", "add", "new"
   - Read target pipeline file's `## Active` table
   - If 2+ keywords match an existing task title, warn user:

   ```
   ⚠️ Similar task found: FEAT-072 "Email service consolidation"
   Keywords overlap: [email, service]

   Options:
   1. Create anyway (different scope)
   2. Cancel and work on existing task
   3. Rename new task
   ```

3. Use AskUserQuestion if potential duplicate found - never auto-skip.

### Step 2: Determine Next Task Number

1. Map section to pipeline file:
   - features → `tasks/pipelines/features.md`
   - infrastructure → `tasks/pipelines/infrastructure.md`
   - security → `tasks/pipelines/security.md`
   - agents → `tasks/pipelines/agents.md`

2. Read pipeline file YAML front-matter:
   ```yaml
   ---
   pipeline: features
   prefix: FEAT
   next_id: 066
   ---
   ```

3. Use `next_id` as the task number
4. Construct full ID: `{prefix}-{next_id}` (e.g., `FEAT-066`)

### Step 3: Create Task Detail File

1. Read `tasks/templates/task_spec.md` for structure
2. Create new file at `tasks/detail/{prefix-lowercase}-{next_id}-{task-slug}.md`
   - Example: `tasks/detail/feat-066-email-reply-skill.md`
3. Fill in template:

```markdown
# Task: [Task Name]
**Status:** Planning
**Owner:** Claude
**Created:** [YYYY-MM-DD from context]
**ID:** [PREFIX-XXX]

## 1. Requirements & Analysis
- **Goal:** [Extract from argument/conversation]
- **Core Constraints:** [TBD - to be filled during planning]
- **Files to Modify:** [TBD]

## 2. Success Metrics (The Tests)
*Define these BEFORE coding.*
- [ ] **Test A:** [TBD]
- [ ] **Test B:** [TBD]

## 3. Implementation Plan
1. [TBD - to be filled during planning]

## 4. Execution Log
| Date | Phase | Action | Result |
|------|-------|--------|--------|
| [Date] | Plan | Created task spec | Ready for planning |
```

### Step 4: Add Entry to Pipeline File

1. Read the pipeline file
2. Find the `## Active` table
3. Add new row:
   ```markdown
   | FEAT-066 | [Task Name] | - | `tasks/detail/feat-066-task-slug.md` | **Planning** | - |
   ```
4. Update YAML front-matter `next_id` to `next_id + 1`

### Step 4.5: Update Master Dashboard (P0/P1 Only)

**If the task priority is P0 or P1:**

1. Read `tasks/master.md`
2. Find the `## Current Focus` section/table
3. Add new row maintaining priority order (P0 first, then P1):
   ```markdown
   | P1 | [Task Name] | [PREFIX-XXX](pipelines/[section].md) | Planning |
   ```

**Skip this step for P2 tasks** - they stay only in pipeline backlog.

### Step 5: Confirm and Offer Next Steps

Output:
```
Created task:
- ID: [PREFIX-XXX]
- Priority: [P0|P1|P2]
- Detail: tasks/detail/[prefix]-[xxx]-[task-slug].md
- Pipeline: tasks/pipelines/[section].md
- Master.md: [Updated | Skipped (P2)]

Next steps:
1. Run `/todo` to see your task queue
2. Edit the detail file to flesh out requirements
3. When ready, change Status to "In Progress"
```

## Section Detection Hints

If no section specified, infer from task description keywords:
- "feature", "ui", "api", "skill", "intent", "routing" → features
- "LXC", "proxmox", "VM", "network", "deploy", "infra", "TLS" → infrastructure
- "security", "auth", "hardening", "CVE", "pen test", "guardrails" → security
- "agent", "subagent", "ollama", "local-", "cost", "telemetry" → agents

## Example Usage

**Input:** `/create-task email-reply-skill --section features`

**Output:**
- Checks for duplicate tasks (slug match, keyword overlap)
- Reads `tasks/pipelines/features.md`, gets `next_id: 071`
- Creates `tasks/detail/feat-071-email-reply-skill.md`
- Adds row to `## Active` table in `tasks/pipelines/features.md`
- Adds row to `tasks/master.md` `## Current Focus` (P1 default)
- Updates `next_id` to `072` in YAML front-matter
- Confirms creation

**Input:** `/create-task` (no args)

**Behavior:** Asks user what task to create and which section

## Error Handling

| Scenario | Action |
|----------|--------|
| Template file missing | Create minimal spec with just header and sections |
| Pipeline file missing | Create it with initial YAML front-matter |
| File already exists at target path | Ask user: overwrite, rename, or cancel |
| Invalid section name | Show valid options and ask again |
| Duplicate slug detected | Warn user, offer: create anyway / cancel / rename |
| Keyword overlap found | Warn user, show similar task, ask how to proceed |
| master.md missing `## Current Focus` | Create the section header and table |
