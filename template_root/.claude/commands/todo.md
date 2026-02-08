---
description: List and manage tasks from pipeline files
argument-hint: [pipeline|ID|next]
allowed-tools:
  - Read
  - Glob
  - Edit
---

# Todo - Project Task Manager

Project-specific todo management that understands our pipeline structure.

## Usage

```
/todo                    # List all active tasks across pipelines
/todo <pipeline>         # Filter to specific pipeline (features, infrastructure, security, agents)
/todo <ID>               # Show details for specific task (e.g., FEAT-065)
/todo next               # Show top priority unblocked task
```

## Instructions

### Mode Detection

Parse $ARGUMENTS to determine mode:
- No args or "all" → List Mode
- Pipeline name (features/infrastructure/security/agents) → Filtered List Mode
- Task ID (matches FEAT-/INF-/SEC-/AGT- pattern) → Detail Mode
- "next" → Next Priority Mode

### List Mode (default)

1. Glob for `tasks/pipelines/*.md`
2. For each pipeline file:
   a. Read YAML front-matter (pipeline name, prefix)
   b. Parse table rows for status
   c. Count: Active (Planning/In Progress), Blocked, Complete
3. Display aggregated view:

```
Active Tasks:

FEATURES (3 active, 1 blocked, 12 complete)
  FEAT-065  Email hallucination fix     In Progress
  FEAT-070  Interactive Telegram test   Planning

INFRASTRUCTURE (2 active, 0 blocked, 5 complete)
  INF-075   Post-crash cleanup          In Progress

SECURITY (0 active, 1 blocked, 8 complete)
  SEC-004   Internal HTTPS              Blocked (infra)

AGENTS (3 active, 0 blocked, 10 complete)
  AGT-077   Master.md restructure       Planning
  AGT-076   Session-scoped telemetry    Planning

Reply with task ID for details, or 'next' for top priority.
```

### Filtered List Mode

If $ARGUMENTS matches a pipeline name (features, infrastructure, security, agents):
- Read only that pipeline file
- Display same format but only for that pipeline
- Show all tasks (active, blocked, complete) for comprehensive view

### Detail Mode

If $ARGUMENTS matches a task ID pattern (e.g., FEAT-065, AGT-077):

1. Parse task ID to get prefix (determines pipeline):
   - FEAT- → features
   - INF- → infrastructure
   - SEC- → security
   - AGT- → agents
2. Read appropriate pipeline file
3. Find task row by ID
4. Extract detail file path from table
5. Read detail file
6. Display:
   - ID, Task Name, Status
   - Owner, Created date
   - Success Metrics (from detail file)
   - Implementation Plan summary (first 3 steps)
7. Offer actions:
   ```
   Actions:
   1. Start working (mark In Progress)
   2. Mark complete
   3. View full detail file
   4. Back to list

   Reply with action number.
   ```

### Next Priority Mode

If $ARGUMENTS is "next":

1. Scan all pipeline files
2. Collect all tasks with status Planning or In Progress
3. Filter out: Complete, Blocked, Deferred
4. Sort by:
   - Priority (P0 > P1 > P2 > unmarked) - check detail file if exists
   - Status (In Progress > Planning)
   - ID number (lower = older = higher priority)
5. Display top task in Detail Mode format
6. Offer to start working if status is Planning

## Status Parsing

Parse from table cells:
- `**Planning**` → Planning (active)
- `**In Progress**` → In Progress (active)
- `**Complete**` → Complete
- `**Blocked**` → Blocked
- `**Deferred**` → Deferred
- `**Ready**` → Ready (active, treat as Planning)

## Table Format Expected

Pipeline files have this structure:

```markdown
---
pipeline: features
prefix: FEAT
next_id: 071
---

# Features Pipeline

## Active

| ID | Task | Phase | Detail | Status | Commit |
|----|------|-------|--------|--------|--------|
| FEAT-065 | Email hallucination | Phase-2.5 | `tasks/detail/...` | **In Progress** | - |

## Backlog

| ID | Task | Priority | Detail | Status |
|----|------|----------|--------|--------|
```

## Edit Capability

If user selects "Start working" or "Mark complete":

1. Read the pipeline file
2. Find row with matching ID
3. Replace status cell:
   - "Start working" → `**In Progress**`
   - "Mark complete" → `**Complete**`
4. Write updated file
5. Confirm: "Updated [ID] status to [new status]"

## Dashboard Integration

After any status change, offer:
```
Task updated. Run `/todo` to see updated list.
```

## Error Handling

| Scenario | Response |
|----------|----------|
| No pipeline files found | "No pipeline files found at tasks/pipelines/. Run `/create-task` to create your first task." |
| Pipeline file missing | "Pipeline file not found: {path}. Run `/create-task --section {name}` to initialize." |
| Task ID not found | "Task {ID} not found in any pipeline. Check the ID and try again." |
| Detail file missing | "Detail file not found at {path}. Task entry exists but detail file needs creation." |
| Invalid action number | "Invalid choice. Please reply with 1, 2, 3, or 4." |

## Quick Reference

| Prefix | Pipeline | Description |
|--------|----------|-------------|
| FEAT- | features | Product capabilities |
| INF- | infrastructure | Ops and deployment |
| SEC- | security | Security hardening |
| AGT- | agents | Claude Code agents |
