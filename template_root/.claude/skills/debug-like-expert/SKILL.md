---
name: debug-like-expert
description: Deep analysis debugging mode for complex issues. Invokes the @debug agent with methodology mode enabled for systematic investigation with cognitive bias awareness and hypothesis testing.
allowed-tools: [Task, Read]
---

<teaming_stub>
<!-- Minimal teaming: doctor awareness only -->
If doctor report exists at /tmp/doctor-report-latest.json:
- Note any active anti-patterns that may be related to the issue being debugged
- Log "debug-like-expert: skill_invoked" to /tmp/teaming-decisions.log
</teaming_stub>

# Debug Like an Expert

This skill invokes the `@debug` agent with methodology mode enabled, providing:
- Cognitive bias awareness (confirmation bias, anchoring, sunk cost)
- Falsifiable hypothesis testing
- Scientific method debugging approach
- Domain expertise loading (if available)

## Usage

When you invoke `/debug`, this skill delegates to the @debug agent with `methodology_mode=true`.

**What you provide**:
- Description of the issue
- Relevant file paths
- Test command to verify fix (optional)

**What happens**:
1. Agent detects this is methodology mode (not fast path)
2. Loads debugging wisdom from reference files
3. Runs Ralph Wiggum iterative test loop with enhanced hypothesis phase
4. Returns resolution or escalates with full context

## Example

```
/debug The email handler test fails intermittently with KeyError.
Files: src/app/handler.py
Test: pytest tests/test_handler.py -v
```

## Invocation

<invoke_agent>
Delegate to @debug agent with:
- methodology_mode: true
- issue: [user's description]
- files: [mentioned files or ask user]
- test_command: [if provided, else ask]
- task_file: [create or ask for task detail file path]
</invoke_agent>

## Direct Methodology Access

For reading the debugging methodology without running the agent:

- **Debugging Mindset**: `references/debugging-mindset.md`
  - Cognitive biases, meta-debugging, when to restart
- **Hypothesis Testing**: `references/hypothesis-testing.md`
  - Falsifiability, evidence quality, experimental design
- **Investigation Techniques**: `references/investigation-techniques.md`
  - Binary search, rubber duck, minimal reproduction
- **Verification Patterns**: `references/verification-patterns.md`
  - Definition of "verified", regression testing
- **Research Strategy**: `references/when-to-research.md`
  - When to search vs experiment

These files remain the source of truth for methodology content.
