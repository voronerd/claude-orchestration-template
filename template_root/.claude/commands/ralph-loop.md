---
name: ralph-loop
description: Start a Ralph Wiggum iterative development loop
arguments: PROMPT [--max-iterations N] [--completion-promise 'TEXT']
allowed-tools: [Bash]
---

# Ralph Loop Command

Start an iterative self-referential loop where Claude works on the same prompt
repeatedly, seeing previous work in files between iterations.

## Usage

```
/ralph-loop <prompt> [--max-iterations N] [--completion-promise 'TEXT']
```

## How It Works

1. Creates a state file at `.claude/ralph-loop.local.md`
2. The Stop hook intercepts exit attempts
3. Same prompt is fed back with iteration counter
4. Previous work persists in files and git history
5. Loop continues until max iterations or completion promise detected

## Options

- `--max-iterations N`: Stop after N iterations (default: unlimited)
- `--completion-promise 'TEXT'`: Stop when `<promise>TEXT</promise>` is output

## Examples

```bash
# Debug with max 10 attempts
/ralph-loop "Fix the failing test in auth.py" --max-iterations 10

# Build until done
/ralph-loop "Build a REST API for todos" --completion-promise "ALL TESTS PASSING"

# Unlimited iterations (careful!)
/ralph-loop "Refactor the cache layer"
```

## Execution

Run the setup script:

```bash
./scripts/setup-ralph-loop.sh $ARGUMENTS
```

## Stopping

- Reach `--max-iterations` limit
- Output `<promise>YOUR_PROMISE</promise>` (must be TRUE!)
- Run `/cancel-ralph` to manually stop

## Integration with @debug

For debugging tasks, consider using @debug with `--ralph-driver` flag:
```
@debug issue="..." files=[...] task_file="..." test_command="..." --ralph-driver
```

This runs @debug in single-pass mode suitable for Ralph loop iteration.
