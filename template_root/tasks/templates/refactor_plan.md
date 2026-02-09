# Refactor Plan: [Module/File Name]
**Status:** [Mapping/Digging/Complete]
**Target:** [Path to file(s) being refactored]
**Created:** [YYYY-MM-DD]

---

## Phase 1: MAP (Do This First!)

*Before touching any code, document what exists. This prevents hallucinating imports that don't exist.*

### 1.1 Public Interface
*What do other files import from this module?*

| Export | Type | Used By |
|--------|------|---------|
| `functionName` | function | `file1.js`, `file2.js` |
| `ClassName` | class | `file3.js` |
| `CONSTANT` | const | `file4.js` |

### 1.2 Dependencies (Imports)
*What does this module depend on?*

| Import | From | Purpose |
|--------|------|---------|
| `dependency` | `./path` | Used for X |
| `library` | `package` | Used for Y |

### 1.3 Internal State
*Variables, caches, singletons that persist across calls.*

| Name | Type | Scope | Notes |
|------|------|-------|-------|
| `_cache` | Map | module | Cleared on reset |

### 1.4 Side Effects
*Does this module do anything on import? Timers? Event listeners?*

- [ ] Registers event listeners
- [ ] Starts timers/intervals
- [ ] Modifies global state
- [ ] Makes network requests
- [ ] Writes to filesystem

---

## Phase 2: RISK ANALYSIS

### 2.1 Breaking Changes
*What could break if we change this?*

| Change | Risk | Mitigation |
|--------|------|------------|
| Rename function | High - used in 5 files | Find/replace all usages first |
| Change signature | Medium - 2 callers | Update callers in same commit |

### 2.2 Test Coverage
*What tests exist? What's missing?*

- [ ] Unit tests exist: [path]
- [ ] Integration tests exist: [path]
- [ ] No tests - need to add before refactoring

### 2.3 Rollback Plan
*How do we undo this if it breaks production?*

```
git revert [commit-hash]
```

---

## Phase 3: DIG (Refactoring Plan)

*Only fill this out AFTER completing the MAP phase.*

### 3.1 Goals
*What are we trying to achieve?*

1. [Goal 1: e.g., "Reduce complexity"]
2. [Goal 2: e.g., "Improve testability"]

### 3.2 Step-by-Step Changes

| Step | Change | Files Affected | Test After? |
|------|--------|----------------|-------------|
| 1 | [First change] | `file.js` | Yes |
| 2 | [Second change] | `file.js`, `other.js` | Yes |

### 3.3 Verification Checklist
- [ ] All existing tests pass
- [ ] New tests added for changed behavior
- [ ] No new linter warnings
- [ ] Manual smoke test completed

---

## Execution Log

| Date | Phase | Action | Result |
|------|-------|--------|--------|
| [Dt] | Map | Documented public interface | Done |
| [Dt] | Map | Listed all dependencies | Done |
| [Dt] | Dig | [Refactoring step] | [Result] |
