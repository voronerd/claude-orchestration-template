---
name: cancel-ralph
description: Cancel active Ralph Wiggum loop
allowed-tools: [Bash]
hidden: true
---

# Cancel Ralph Loop

Stop an active Ralph Wiggum loop by removing the state file.

## Execution

Check if a loop is active and cancel it:

```bash
if [[ -f .claude/ralph-loop.local.md ]]; then
  ITERATION=$(grep '^iteration:' .claude/ralph-loop.local.md | sed 's/iteration: *//')
  rm .claude/ralph-loop.local.md
  echo "Ralph loop cancelled at iteration $ITERATION"
else
  echo "No active Ralph loop"
fi
```
