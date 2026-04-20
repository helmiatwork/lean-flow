---
name: nyquist-auditor
description: Fill test coverage gaps after execution. Generates behavioral tests for uncovered requirements. Read-only on implementation — only creates/modifies test files.
---

# lean-flow: nyquist-auditor

Tests that don't exist can't catch bugs. This skill finds uncovered requirements and writes the missing tests.

## When to invoke
After verifier passes, before the final PR. Or any time test coverage feels thin on a completed feature.

## Core constraint
**Never modify implementation files.** Only creates or modifies:
- Test files (`*.test.ts`, `*.spec.ts`, `__tests__/*.ts`, etc.)
- Test fixtures
- Test helpers

If a test reveals a bug in implementation, escalate — do NOT fix the implementation here.

## Process

### Step 1 — Detect test framework
Explorer checks:
- `package.json` for Jest/Vitest/Mocha/pytest/RSpec
- Existing test file conventions (naming, directory structure, import patterns)
- Test command in package.json scripts

### Step 2 — Map requirements → tests
For each confirmed requirement from the discuss phase:
- Search for existing test covering it
- If found: verify it's behavioral (tests observable output, not internal structure)
- If missing: mark as gap

### Step 3 — Classify gaps
| Gap type | Description |
|----------|-------------|
| Missing test file | No tests exist for this module at all |
| Missing behavioral test | Tests exist but only cover internals, not user-observable behavior |
| Missing edge case | Happy path tested, error/edge cases not |
| Missing integration | Unit tests exist, but component interactions untested |

### Step 4 — Generate tests
For each gap, dispatch **fixer** to write:
- Behavioral tests (what the user/system observes, not how code works internally)
- Edge cases (empty input, invalid input, boundary values)
- Error handling (what happens when things go wrong)

Test quality rules:
- Tests must be runnable and pass against current implementation
- Each test has a clear description of what behavior it verifies
- No testing implementation details (private methods, internal state)

### Step 5 — Verify tests pass
Run test suite. If new tests fail:
- If failing because implementation is wrong: escalate, do NOT fix implementation
- If failing because test is wrong: fix the test

### Output
```
## Nyquist Audit: [feature]

### Coverage gaps filled
- [requirement]: added [test file] — [N] tests
- [requirement]: added edge cases to [existing test file]

### Tests run: [N passed / N total]

### Escalations (implementation issues found)
- [description] — needs fixer to resolve
```

## Rules
- Behavioral tests only — test what users observe, not how code works
- Never modify implementation files
- If a requirement genuinely can't be tested automatically, document why
- Prefer adding to existing test files over creating new ones when structure allows
