# Adversarial Test Spec: [Feature Name]
**Status:** [Draft/Ready/Executed]
**Target:** [Function/Module being tested]
**Created:** [YYYY-MM-DD]

## 1. Happy Path (The Obvious Case)
*What should work when everything is perfect?*

| Input | Expected Output |
|-------|-----------------|
| [X] | [Y] |

## 2. Edge Cases (The Critic's List)
*Think adversarially: how can this break?*

### Boundary Conditions
- [ ] Null/undefined inputs
- [ ] Empty arrays/strings/objects
- [ ] Max/min integer values
- [ ] Zero values
- [ ] Negative numbers (if applicable)

### Failure Scenarios
- [ ] Network timeout / unreachable service
- [ ] Auth failure / expired token
- [ ] Invalid data format / malformed JSON
- [ ] Rate limiting / quota exceeded
- [ ] Partial failure (some items succeed, some fail)

### State Issues
- [ ] Concurrent access / race conditions
- [ ] Stale data / cache invalidation
- [ ] Missing dependencies / uninitialized state
- [ ] Operation interrupted mid-way

### Security Considerations
- [ ] Injection attacks (if user input involved)
- [ ] Unauthorized access attempts
- [ ] Data leakage in error messages

## 3. Failing Tests to Write First
*List specific tests. These MUST fail initially.*

1. `test_[feature]_null_input()` - Expects: [graceful error / default value]
2. `test_[feature]_timeout()` - Expects: [retry / error message]
3. `test_[feature]_[edge_case]()` - Expects: [behavior]

## 4. Implementation Constraints
*Rules the implementation must follow.*

- [ ] Must not crash the gateway
- [ ] Must log errors with context
- [ ] Must return consistent error format
- [ ] [Other constraints...]

## 5. Execution Log
| Date | Test | Result | Notes |
|------|------|--------|-------|
| [Dt] | All edge cases | FAIL | Expected - proceeding to implement |
