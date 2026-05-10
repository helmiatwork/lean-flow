---
name: test
description: Run full test suite and report pass/fail summary with failure details.
---

# /lean-flow:test

Execute full project test suite and report results. Parses pass/fail summary. Non-blocking audit (reports only; does not halt).

## Step 1 — Detect test runner

Scan for test framework and entry point:

```bash
# Check for common test scripts
TEST_CMD=""
TEST_LOG="/tmp/test-output.log"

if [ -f "tests/run-all.sh" ]; then
  TEST_CMD="bash tests/run-all.sh"
elif [ -f "package.json" ] && grep -q '"test"' package.json; then
  TEST_CMD="npm test"
elif [ -f "Gemfile" ] && command -v bundle >/dev/null; then
  TEST_CMD="bundle exec rspec"
elif command -v pytest >/dev/null; then
  TEST_CMD="pytest"
elif [ -f "Makefile" ] && grep -q "^test:" Makefile; then
  TEST_CMD="make test"
else
  echo "❌ No test command detected."
  echo "   Checked: tests/run-all.sh, npm test, bundle exec rspec, pytest, make test"
  exit 0
fi
```

## Step 2 — Run tests

Execute test command with logging:

```bash
echo "Running: $TEST_CMD"
echo "---"

eval "$TEST_CMD" 2>&1 | tee "$TEST_LOG"
TEST_EXIT=$?

echo "---"
echo "Exit code: $TEST_EXIT"
```

## Step 3 — Parse summary

Extract pass/fail counts from log output. Common patterns:

**npm/jest:**
```bash
PASS_COUNT=$(grep -o "Tests:.*passed" "$TEST_LOG" | grep -o "[0-9]\+" | head -1)
FAIL_COUNT=$(grep -o "Tests:.*failed" "$TEST_LOG" | grep -o "[0-9]\+" | head -1)
```

**RSpec:**
```bash
PASS_COUNT=$(grep -o "[0-9]\+ examples" "$TEST_LOG" | grep -o "[0-9]\+")
FAIL_COUNT=$(grep -o "[0-9]\+ failures" "$TEST_LOG" | grep -o "[0-9]\+")
```

**pytest:**
```bash
PASS_COUNT=$(grep -o "[0-9]\+ passed" "$TEST_LOG" | grep -o "[0-9]\+")
FAIL_COUNT=$(grep -o "[0-9]\+ failed" "$TEST_LOG" | grep -o "[0-9]\+")
```

If counts cannot be parsed, default to exit code (0 = pass, non-0 = fail).

## Step 4 — Render report

Render markdown summary:

**If all tests pass (FAIL_COUNT == 0):**

```markdown
# Test Report

✅ All tests passed

| Metric | Value |
|--------|-------|
| Passed | $PASS_COUNT |
| Failed | 0 |
| Exit code | $TEST_EXIT |
| Command | $TEST_CMD |

No action required.
```

**If any tests fail (FAIL_COUNT > 0):**

```markdown
# Test Report

❌ Test failures detected

| Metric | Value |
|--------|-------|
| Passed | $PASS_COUNT |
| Failed | $FAIL_COUNT |
| Exit code | $TEST_EXIT |
| Command | $TEST_CMD |

## Failed test details (last 30 lines)

\`\`\`
<last-30-lines-of-$TEST_LOG>
\`\`\`

## Next steps

1. Review failures above (or full log: $TEST_LOG)
2. Fix failing tests or code
3. Rerun: $TEST_CMD
4. Commit: git add . && git commit -m "fix: resolve test failures"

This is informational. No blocking failure.
```

## Step 5 — Exit code passthrough

Exit with the same code as test command (0 if pass, non-0 if fail). This allows parent workflows to react if needed, but this command itself does not halt.

## Hard rules

- **Non-blocking audit.** Reports results; does not prevent further work.
- **Preserve test log.** Keep `/tmp/test-output.log` for inspection.
- **No automatic fixes.** User fixes failing tests manually.
- **No modifications to test files.** Read-only inspection.
- **Graceful fallback.** If test runner not detected, explain what to check and exit cleanly.
- **Last 30 lines for failures.** Enough context for quick diagnosis without overwhelming output.
- **Parse robustly.** If summary line format is non-standard, fall back to exit code heuristic.
