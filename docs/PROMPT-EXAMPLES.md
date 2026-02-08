# Prompt Examples

> **The Cookbook**: Copy-pasteable prompts and agent commands.
> **Read [WORKFLOW.md](WORKFLOW.md) first** if you're new to the system.

Real-world examples from production use showing how to use the orchestration system effectively.

For daily workflow procedures and lifecycle rules, see [WORKFLOW.md](WORKFLOW.md).

---

## Part 1: Core Workflow

The primary workflow is: **create-task → create-prompt → run-prompt**

### 1.1 The Task Dashboard (`tasks/master.md`)

Before creating tasks, understand how `tasks/master.md` works. It's the central dashboard that tracks all work.

**Structure:**
```
tasks/
├── master.md              # Central dashboard (priority tiers, status)
├── pipelines/             # Pipeline-specific backlogs
│   ├── features.md        # FEAT-* tasks
│   ├── infrastructure.md  # INF-* tasks
│   ├── security.md        # SEC-* tasks
│   └── agents.md          # AGT-* tasks
├── detail/                # Active task specifications
│   └── feat-080-*.md      # Detailed spec for FEAT-080
└── done/                  # Archived completed tasks
```

**Priority Tiers:**
| Tier | Meaning | WIP Limit |
|------|---------|-----------|
| P0 | Do Now (critical path) | Combined P0+P1 ≤ 12 |
| P1 | Active Work (next in queue) | |
| P2 | Groomed, don't touch yet | No limit |
| P3 | Backlog (future work) | No limit |

**How it's used:**
- Session start: Claude reads `master.md` to understand current priorities
- Task selection: Pick from P0/P1, not P2/P3
- Progress tracking: Tasks move through statuses (Planning → In Progress → Complete)
- Pipeline alignment: @overseer and @doctor check if work aligns with `master.md`

**Example master.md entry:**
```markdown
### P0 - Do Now (Critical Path)

| Task | Pipeline | Status | Notes |
|------|----------|--------|-------|
| PAI-PORT-02: ModelRouter | [FEAT-081](pipelines/features.md) | Planning | Critical path blocker |
```

---

### 1.2 Creating Tasks with `/create-task`

Tasks are work items tracked in the pipeline. Use `/create-task` to create them with proper spec files and pipeline integration.

**What `/create-task` does:**
1. Creates spec file in `tasks/detail/[task-id]-[name].md`
2. Adds entry to appropriate pipeline file (`tasks/pipelines/*.md`)
3. Optionally adds to `master.md` at specified priority tier

**Basic feature task:**
```
/create-task Add retry logic to the webhook handler

This should:
- Implement exponential backoff (1s, 2s, 4s, 8s max)
- Log retry attempts with structlog
- Give up after 4 attempts with error notification
```

**Infrastructure task (creates new modules):**
```
/create-task Create a rate limiter service

Scope: Infrastructure (new service)
Integration targets: api_router.py, middleware/__init__.py

Requirements:
- Token bucket algorithm
- Per-user rate limits from config
- Redis backend for distributed state
```

**Task with explicit dependencies:**
```
/create-task Wire EffortClassifier into router

Blocked by: PAI-PORT-01 (EffortClassifier must exist first)

This task:
- Imports EffortClassifier from routing/effort_classifier.py
- Calls classify() before model selection
- Routes to effort-specific model aliases
```

---

### 1.3 Creating Prompts with `/create-prompt`

Prompts are executable specifications that agents can run. The skill walks you through requirements gathering.

**Simple feature prompt:**
```
/create-prompt Add email search to the bot

Users should be able to say "search my email for invoices from last month"
and get matching results.
```

The skill will:
1. Ask clarifying questions (scope, output format, etc.)
2. Analyze complexity and determine single vs multi-prompt
3. Generate XML-structured prompt with verification steps
4. Save to `prompts/NNN-descriptive-name.md`

**Example generated prompt** (from FEAT-080 EffortClassifier):

```xml
<objective>
Create an EffortClassifier that categorizes user requests into TRIVIAL, QUICK,
STANDARD, THOROUGH, or DETERMINED effort levels. This classification determines
model alias routing (via `model_aliases.yaml`) and whether to invoke The Algorithm.
</objective>

<context>
@tasks/detail/feat-080-pai-port-01-effort-classifier.md
@config/model_aliases.yaml
</context>

<requirements>
- [ ] `EffortLevel` enum with 5 levels
- [ ] `EffortClassifier.classify(message: str) -> EffortClassification`
- [ ] Keyword-based classification with override detection
- [ ] Unit tests with 10+ test cases covering each level
</requirements>

<agent_routing>
| Step | Agent | Cost | Notes |
|------|-------|------|-------|
| Implementation | @local-coder | FREE | Generates code |
| Review | @reviewer | FREE | Quality check |
| Tests | @tester | FREE | Generate test cases |
| Wiring check | @integration-check | FREE | Verify exports |
</agent_routing>

<output>
Create/modify files:
- `./src/app/routing/effort_classifier.py`
- `./src/app/models/effort.py`
</output>

<verification>
```bash
pytest tests/test_effort_classifier.py -v
```
</verification>

<success_criteria>
- [ ] All tests pass (10+ test cases)
- [ ] @reviewer approves
- [ ] @integration-check passes (exports in __init__.py)
</success_criteria>
```

**Infrastructure prompt with integration checkpoint:**
```
/create-prompt Create daily brief service

This is an infrastructure task creating a new service module.
Port from scripts/daily-brief.py to the application architecture.
```

The skill asks: "Which file(s) will import/wire this new code?"
You answer: "registry/tools.yaml and the dynamic handler loader"

Generated prompt includes:
```xml
<integration_reminder>
Integration target(s): registry/tools.yaml, handler loader
After implementation, verify this code is imported/wired in the above file(s).
</integration_reminder>
```

---

### 1.4 Running Prompts with `/run-prompt`

Execute prompts with automatic agent routing and post-execution verification.

**Run single prompt:**
```
/run-prompt 001
```

**Run multiple prompts in parallel (independent tasks):**
```
/run-prompt 005 006 007 --parallel
```

**Run multiple prompts sequentially (dependencies):**
```
/run-prompt 001 002 003 --sequential
```

**What happens during execution:**
1. Teaming checks (doctor report, cost tier)
2. Agent routing based on prompt metadata
3. Execution via appropriate agent (@local-coder, etc.)
4. Post-execution verification
5. Integration check if infrastructure
6. Deployment prompt if application code modified

**Example teaming log entry:**
```
2026-02-06T05:48:26+00:00 PROMPT: 001-effort-classifier.md |
AGENTS: @local-coder(FREE), @reviewer(FREE), @tester(FREE), @integration-check(FREE) |
RESULT: PASS | COMMIT: 531e796
```

---

## Part 2: Planning with `/create-plans`

The planning skill creates different types of plans based on your needs.

### 2.1 Development/Integration Plans

Standard plans for building features with clear implementation steps.

```
/create-plans Phase 3 of the PAI porting project

We're implementing the personalization layer:
- TELOS directory structure
- TelosService for reading user preferences
- ProfileService for user profiles

Depends on: Phase 2 (MemoryService must exist)
```

**Generated plan structure:**
```
.planning/phases/03/
├── 03-01-PLAN.md      # TELOS directory (2-3 tasks)
├── 03-02-PLAN.md      # TelosService (2-3 tasks)
├── 03-03-PLAN.md      # ProfileService (2-3 tasks)
└── SUMMARY.md         # Created after execution
```

Each PLAN.md contains:
- Objective with context
- 2-3 focused tasks (scope-controlled)
- Verification commands
- Success criteria checkboxes

### 2.2 Research Plans

Deep research for exploration, evaluation, and decision-making.

```
/create-plans Research: Evaluate vector database options for memory layer

I need to understand:
- Qdrant vs Pinecone vs Weaviate vs ChromaDB
- Self-hosted vs managed tradeoffs
- Python client quality and async support
- Cost at 10M vectors scale

Produce: Decision document with recommendation
```

**Generated research plan:**
```markdown
<research_plan>
<phase name="landscape">
Map the vector DB space: major players, open-source vs proprietary,
deployment models. Use @gemini-overseer for initial research.
</phase>

<phase name="evaluation">
Evaluate top 3 candidates against criteria. Create comparison matrix.
Test Python clients for ergonomics.
</phase>

<phase name="decision">
Synthesize findings into recommendation. Run @overseer for
multi-model validation of the decision.
</phase>
</research_plan>
```

### 2.3 Investigation Plans

When you don't know what you're building yet.

```
/create-plans Investigate: How does the existing email scoring work?

I need to understand the current implementation before improving it.
Map the code flow, identify the scoring heuristics, document the
data structures involved.
```

**Produces:**
```
.planning/investigations/email-scoring/
├── BRIEF.md           # What we're investigating
├── 01-RESEARCH-PLAN.md  # Exploration strategy
├── FINDINGS.md        # Discovered knowledge
└── SUMMARY.md         # Final synthesis
```

### 2.4 Migration/Porting Plans

For moving code between systems.

```
/create-plans Port PAI features to example-bot

Source: Personal_AI_Infrastructure/ (reference implementation)
Target: src/app/

Features to port:
1. EffortClassifier
2. ModelRouter
3. MemoryService (Qdrant-based)
4. The Algorithm state machine

Create task specs with dependency graph.
```

**Produces wave-based execution plan:**
- Wave 1: Routing foundation (no dependencies)
- Wave 2: Memory layer (builds on Wave 1)
- Wave 3: Personalization (builds on Wave 2)
- Wave 4: Enhancement (builds on all)

---

## Part 3: Using Subagents for Context Shedding

Subagents preserve your main context by doing heavy lifting in isolated sessions.

### 3.1 Why Context Shedding Matters

**The problem:**
- Large conversations degrade Claude's quality (40-50% context = "completion mode")
- Reading many files bloats context rapidly
- Planning references can add 20k+ tokens

**The solution:**
Delegate to subagents who work in fresh context, returning only summaries.

### 3.2 Subagent Delegation Pattern

```
# Instead of this (main context bloat):
Read all 50 test files
Analyze each one for patterns
Summarize findings

# Do this (context shedding):
Task(
  subagent_type="Explore",
  prompt="Find all test files and analyze patterns. Return only: (1) list of test files, (2) common patterns found, (3) gaps in coverage"
)
```

**Main context receives:** ~100 tokens summary
**Work done:** 50 file reads in isolated context

### 3.3 Common Subagent Patterns

**Exploration (read-only, no edits):**
```
Task(
  subagent_type="Explore",
  prompt="""
  Find all email handlers in src/app/.
  For each handler, report:
  - File path and function name
  - What intents it handles
  - Dependencies it imports

  Return concise summary only.
  """
)
```

**Code generation (isolated editing):**
```
Task(
  subagent_type="local-coder",
  prompt="""
  Create effort_classifier.py with:
  - EffortLevel enum (5 levels)
  - EffortClassifier class with classify() method
  - Keyword patterns from @Reference/EffortMatrix.md

  Use local Ollama model.
  Return: file path and brief description of implementation.
  """
)
```

**Bulk task creation (orchestration):**
```
Task(
  subagent_type="general-purpose",
  prompt="""
  Create 8 tasks for Wave 2 using /create-task skill.
  Read specs from: .planning/04-TASK-SPECS.md

  Tasks to create: [list with blockers]

  Return ONLY: list of created task files and any errors.
  """
)
```

### 3.4 Context Usage Comparison

| Approach | Context Usage |
|----------|---------------|
| Direct file reads (50 files) | ~50,000 tokens |
| Subagent with summary return | ~100 tokens |
| Savings | 99.8% |

---

## Part 4: Agent Use Cases

How to use each agent type effectively.

### 4.1 @overseer - Multi-Model Architecture Review

**Use for:** High-stakes decisions, integration validation, design review. When API keys are available it invokes the biggest models available (at this time) in Gemini, OpenAI and Grok to review - and then Opus compares their judgement to make a decision.

**Pipeline alignment:** @overseer reads `tasks/master.md` and flags work as ON-PIPELINE or UNPLANNED. If you're working on something not in the dashboard, it will warn you.

**How to invoke:**
```
"@overseer, review the auth refactor architecture before I proceed"

"Get @overseer to validate whether this service fits existing patterns"

"I'm stuck deciding between WebSockets and SSE - have @overseer weigh in"

"The task is to add a caching layer. Get @overseer to review the
proposed Redis integration for architectural fit"
```

**What happens:**
- Gets Gemini + OpenAI + Grok perspectives
- Checks if work aligns with master.md priorities
- Opus synthesizes final verdict with confidence levels

**Output format:**
- Models Used: [Gemini ✓] [OpenAI ✓] [Grok ✓]
- Unanimous findings (highest confidence)
- Majority findings (high confidence)
- Individual perspectives
- Opus synthesis and verdict

### 4.2 @doctor - Session Health Diagnostician

**Use for:** Stuck loops, cost waste detection, session hygiene

**Pipeline alignment:** @doctor correlates session activity with `tasks/master.md` to identify if you're working on planned vs unplanned work. Flags sessions that drift from priorities.

**How to invoke:**
```
"@doctor, I've tried 3 different fixes and keep getting the same error"

"Something feels off - get @doctor to run diagnostics on this session"

"@doctor, check if we're routing correctly to local models or wasting money"

"This session has been going a while. @doctor, check for context rot"

"@doctor, work with @integration-check to see if my new code is orphaned"
```

**What happens:**
- Analyzes session patterns for anti-patterns (STUCK_LOOP, ORPHANED_INFRASTRUCTURE)
- Reviews agent call patterns for cost waste
- Checks for ghost code and context rot
- Produces health report with actionable fixes

**Output:** Health report (markdown) + JSON for programmatic consumption (`/tmp/doctor-report-latest.json`)

### 4.3 @debug - Deep-Dive Debugging

**Use for:** Persistent bugs, test failures, logic errors

**How to invoke:**
```
"@debug, tests keep failing with KeyError: 'user_id' in handler.py"

"I've tried 3 fixes and nothing works. @debug, take over and figure this out"

"@debug, investigate why the webhook returns 500 intermittently.
Log findings to tasks/detail/feat-044.md"

"Get @debug to run the Ralph Wiggum loop on this flaky test until it's fixed"

"@debug, work with @tester to create a regression test after you fix this"
```

**Structured invocation (for complex issues):**
```
@debug, investigate this issue:
- issue: Tests fail with KeyError: 'user_id'
- files: src/app/handler.py
- task_file: tasks/detail/feat-044.md
- test_command: pytest tests/test_handler.py -v
```

**Capabilities:**
- Ralph Wiggum pattern (iterative test loops)
- Hypothesis tracking (avoids retrying failed approaches)
- Graph queries for call chain analysis
- Automatic escalation when stuck

### 4.4 @integration-check - Post-Build Verification

**Use for:** Verify new code is wired, not orphaned

**How to invoke:**
```
"@integration-check, verify the new effort_classifier.py is properly wired"

"I just created 3 new files. @integration-check, make sure they're not orphaned"

"Get @integration-check to verify exports in routing/__init__.py"

"@integration-check, the files are effort_classifier.py and effort.py.
They should be imported by router.py"
```

**Structured invocation:**
```
@integration-check, verify these new files are integrated:

created_files:
- src/app/routing/effort_classifier.py
- src/app/models/effort.py

integration_targets:
- src/app/routing/__init__.py
- src/app/routing/router.py

test_command: python -c "from src.routing import EffortClassifier"
```

**Checks:**
- Exports in __init__.py files
- Import statements in consuming files
- No orphaned code (created but never used)

### 4.5 @code-sentinel - Security Audit

**Use for:** Security review, vulnerability scanning

**How to invoke:**
```
"@code-sentinel, review auth.py for security vulnerabilities"

"Before I deploy this, get @code-sentinel to check for injection vectors"

"@code-sentinel, audit the new secrets management code for hardcoded credentials"

"I'm handling user input here. @code-sentinel, check for XSS and injection"

"@code-sentinel, do a full security review of src/app/auth/"
```

**What happens:**
- Runs Gemini + OpenAI + Grok security analysis in parallel
- Grok acts as "chaos engineer" for creative abuse scenarios
- Produces findings with severity ratings (CRITICAL/HIGH/MEDIUM/LOW)
- Never fixes code - only finds vulnerabilities

### 4.6 @local-coder - FREE Code Generation

**Use for:** All code drafting (via local Ollama)

**How to invoke:**
```
"Add retry logic with exponential backoff to the webhook handler"
→ Automatically routes to @local-coder

"@local-coder, create an EffortClassifier with 5 effort levels"

"Write a rate limiter using token bucket algorithm"
→ Automatically routes to @local-coder

"@local-coder, refactor this function to be async and add proper error handling"
```

**What happens:**
- Uses local Ollama model on GPU server
- Zero cloud API cost
- Hook enforcement prevents accidental Claude API usage
- Returns code + brief explanation

### 4.7 @reviewer / @tester - Quality Pipeline

**How to invoke @reviewer:**
```
"@reviewer, check the code @local-coder just generated"

"Get @reviewer to look at effort_classifier.py for quality issues"

"@reviewer, is this implementation following our existing patterns?"

"Before I merge, @reviewer do a quick review of my changes"
```

**How to invoke @tester:**
```
"@tester, generate tests for the EffortClassifier"

"@tester, create edge case tests for the email parser"

"@tester, work with @reviewer to ensure we have regression tests for that bugfix"

"Get @tester to write 10+ test cases covering all effort levels"
```

**Collaboration pattern:**
```
"@local-coder, implement the rate limiter. Then @reviewer check it,
and @tester generate tests."
```

**Order matters:**
1. @local-coder generates code
2. @reviewer reviews (finds issues before tests written)
3. @tester generates tests (for clean, reviewed code)

---

## Part 5: Agent Collaboration Patterns

How agents work together and call each other.

### 5.1 Hub-and-Spoke Topology

**You (Lead Engineer) are the Hub.** All agents are spokes.

```
                    You (Hub)
                       │
    ┌──────┬──────┬────┴────┬──────┬──────┐
    │      │      │         │      │      │
@local  @debug  @overseer  @code   @int   @doctor
-coder                    -sentinel -check
```

**Rules:**
- Spokes NEVER spawn other spokes
- Spokes may RECOMMEND other agents in output
- Hub decides whether to invoke recommendations

**Why?** Prevents circular dependencies, context explosion, runaway cost.

### 5.2 Agent Recommendation Pattern

Agents recommend but don't invoke:

```markdown
## Debug Agent Output

Fixed: Added null check in handler.py

### Recommendations
- [ ] @integration-check: Verify new error path is tested
- [ ] @tester: Generate regression test for this fix (ALWAYS after bugfix)
- [ ] @code-sentinel: Review error message for info leakage
```

You (Hub) decide: "Run @tester for regression test, skip the others"

### 5.3 Parallel Agent Execution

When tasks are independent, launch multiple agents simultaneously:

```
# Good: Independent research (single message, multiple Task calls)
<Task subagent_type="Explore">Find all email handlers</Task>
<Task subagent_type="Explore">Find all calendar handlers</Task>
<Task subagent_type="gemini-overseer">Review auth architecture</Task>

# Bad: These depend on each other
<Task subagent_type="local-coder">Write the auth module</Task>
# WAIT for result
<Task subagent_type="local-coder">Write tests using auth module</Task>
```

### 5.4 Sequential Agent Chains

When outputs feed into inputs:

```
# Step 1: Generate code
@local-coder → produces effort_classifier.py

# Step 2: Review code (needs Step 1 output)
@reviewer → reviews effort_classifier.py, suggests changes

# Step 3: Generate tests (needs reviewed code)
@tester → creates tests for reviewed code

# Step 4: Verify integration (needs all files)
@integration-check → confirms wiring
```

### 5.5 Escalation Patterns

**@debug escalates to @doctor:**
```
# @debug detects it's stuck (same error 5 times)
→ Returns: "ESCALATE: Session health issue, not code bug"
→ You invoke @doctor for session diagnostics
```

**@gemini-overseer escalates to @overseer:**
```
# Single-model review finds complex architectural issue
→ Returns: "ESCALATE: High-stakes decision, recommend multi-model panel"
→ You invoke @overseer for full panel review
```

**@local-coder escalates to @reviewer:**
```
# Code generated, >20 LOC or new public API
→ Returns: "RECOMMEND: @reviewer for quality check"
→ You invoke @reviewer (or skip for trivial changes)
```

### 5.6 Cost-Conscious Collaboration

**Waterfall principle:** Start FREE, escalate only when needed. See [WORKFLOW.md Cost-Conscious Waterfall](WORKFLOW.md#the-cost-conscious-waterfall) for tier definitions.

```
Attempt 1: @local-orchestrator (FREE)
  → "Can route to @local-coder"

Attempt 2: @local-coder (FREE)
  → Code generated, minor issues

Attempt 3: @reviewer (FREE → PAID if escalates)
  → "Looks good, LGTM"

No paid agents needed!
```

**Only escalate when:**
- Local model produces incorrect output
- Security/architecture decision needed
- Multi-model validation required
- Stuck loop detected

### 5.7 Orchestration Prompts (Meta-Level)

Create prompts that orchestrate multiple agents:

```xml
<workflow>
<wave id="1">
  <create_tasks>
    Task(subagent_type="general-purpose", ...)
  </create_tasks>
  <dependency_validation>
    Task(subagent_type="overseer", ...)
  </dependency_validation>
  <spec_quality_check>
    Task(subagent_type="doctor", ...)
  </spec_quality_check>
  <gate>
    STOP if @doctor returns HIGH severity.
  </gate>
</wave>
</workflow>
```

**This pattern:**
- Main context sees only summaries
- Each wave validates before proceeding
- Failures stop the pipeline early

---

## Quick Reference

> **Skill/Agent cost reference.** For action-oriented "want to do X, say Y" guidance, see [WORKFLOW.md Quick Reference](WORKFLOW.md#quick-reference).

| Task | Skill/Agent | Cost |
|------|-------------|------|
| Create tracked task | `/create-task` | FREE |
| Create executable prompt | `/create-prompt` | FREE |
| Run prompt with routing | `/run-prompt` | FREE→PAID |
| Create implementation plan | `/create-plans` | FREE |
| Create research plan | `/create-plans Research:` | FREE→PAID |
| Explore codebase | `@Explore` | FREE |
| Generate code | `@local-coder` | FREE |
| Review code quality | `@reviewer` | FREE→PAID |
| Generate tests | `@tester` | FREE→PAID |
| Verify integration | `@integration-check` | FREE |
| Debug issues | `@debug` | FREE→PAID |
| Security audit | `@code-sentinel` | PAID |
| Architecture review | `@overseer` | PAID |
| Session health check | `@doctor` | FREE→PAID |
| Quick arch check | `@gemini-overseer` | PAID |
| Git operations | `@local-git` | FREE |

---

## Teaming Log Examples

All workflow decisions are logged to `/tmp/teaming-decisions.log`:

```
# Simple feature
2026-02-05T02:41:53 [run-prompt] [FEAT-077] status=COMPLETE integration=PASS deployment=LXC<ID> tests=31passed agent=@local-coder cost=FREE

# Infrastructure with overseer review
2026-02-04T20:50:35 create-prompt: AGT-085 scope=infrastructure files=4 strategy=sequential teaming=@overseer-complete

# Parallel execution
2026-02-05T00:39:22 run-prompt | AGT-093 | PARALLEL | @local-coder x2 | Fixed run-prompt + create-prompt | PASS

# Doctor violation caught
2026-02-05T02:23:43 [doctor] [VIOLATION] SKILL_BYPASS: spawned agent directly instead of /create-prompt
```
