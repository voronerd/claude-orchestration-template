# Gardener Prompt: Documentation Review

**Use this before closing any task to keep CLAUDE.md healthy.**

---

## Quick Review Checklist

Run through these questions after completing your task:

### 1. New Patterns Introduced?
Did you:
- [ ] Add a new script or tool?
- [ ] Create a new directory or file type?
- [ ] Establish a new coding convention?
- [ ] Add a new dependency or integration?

**If yes → Update the relevant section in CLAUDE.md**

### 2. Existing Rules Changed?
Did you:
- [ ] Modify how tasks are managed?
- [ ] Change the deployment/startup process?
- [ ] Alter configuration file locations?
- [ ] Update troubleshooting steps?

**If yes → Update the affected documentation**

### 3. Common Tasks Affected?
Did you:
- [ ] Add a new workflow or protocol?
- [ ] Create commands others will reuse?
- [ ] Discover gotchas worth documenting?

**If yes → Add to "Common Tasks" or "Troubleshooting"**

---

## Copy-Paste Prompt

Use this prompt in Claude to auto-review your changes:

```
Review the recent changes I made (check git diff or the task execution log).
Compare against CLAUDE.md rules and conventions.

Questions:
1. Did I introduce any new patterns not documented?
2. Did I change anything that contradicts current docs?
3. Should any new troubleshooting entries be added?

If updates are needed, show me the specific edits to CLAUDE.md.
```

---

## When to Skip
- Trivial typo fixes
- Changes entirely within existing documented patterns
- Temporary debugging (reverted before commit)
