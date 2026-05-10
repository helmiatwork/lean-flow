---
name: lint
description: Run language-specific linters (shellcheck, pyflakes, etc.). Non-blocking audit.
---

# /lean-flow:lint

Audit code quality with language-appropriate linters. Reports findings by severity. Non-blocking (informational only; does not fail the command).

## Step 1 — Detect languages in repo

Use `find` to detect which languages are present:

```bash
HAS_BASH=0
HAS_PYTHON=0
HAS_JAVASCRIPT=0
HAS_RUBY=0
HAS_OTHER=0

find . -type f -name "*.sh" 2>/dev/null | grep -q . && HAS_BASH=1
find . -type f -name "*.py" 2>/dev/null | grep -q . && HAS_PYTHON=1
find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \) 2>/dev/null | grep -q . && HAS_JAVASCRIPT=1
find . -type f -name "*.rb" 2>/dev/null | grep -q . && HAS_RUBY=1
```

## Step 2 — Run appropriate linters

For each detected language, run linter (skip if no files found):

### Bash (shellcheck)

```bash
if [ "$HAS_BASH" -eq 1 ]; then
  echo "=== BASH (shellcheck) ==="
  if command -v shellcheck >/dev/null; then
    find plugin/scripts tests/shell -name "*.sh" 2>/dev/null \
      | xargs shellcheck --severity=warning 2>&1 | tee /tmp/lint-bash.log
    BASH_COUNT=$(grep -c "^" /tmp/lint-bash.log || echo "0")
  else
    echo "[SKIP] shellcheck not installed. Install: brew install shellcheck"
    BASH_COUNT="--"
  fi
else
  echo "[SKIP] No .sh files found"
  BASH_COUNT=0
fi
```

### Python (pyflakes)

```bash
if [ "$HAS_PYTHON" -eq 1 ]; then
  echo "=== PYTHON (pyflakes) ==="
  if command -v python3 >/dev/null && python3 -m pyflakes --version >/dev/null 2>&1; then
    find plugin/scripts -name "*.py" 2>/dev/null \
      | xargs python3 -m pyflakes 2>&1 | tee /tmp/lint-python.log
    PYTHON_COUNT=$(grep -c "^" /tmp/lint-python.log || echo "0")
  else
    echo "[SKIP] pyflakes not installed. Install: pip3 install pyflakes"
    PYTHON_COUNT="--"
  fi
else
  echo "[SKIP] No .py files found"
  PYTHON_COUNT=0
fi
```

### JavaScript/TypeScript (eslint, if present)

```bash
if [ "$HAS_JAVASCRIPT" -eq 1 ]; then
  echo "=== JAVASCRIPT/TYPESCRIPT (eslint) ==="
  if [ -f ".eslintrc" ] || [ -f ".eslintrc.json" ] || [ -f "eslint.config.js" ]; then
    if command -v eslint >/dev/null || [ -d "node_modules/.bin" ]; then
      npx eslint . --max-warnings 0 2>&1 | tee /tmp/lint-js.log
      JS_COUNT=$(grep -c "^" /tmp/lint-js.log || echo "0")
    else
      echo "[SKIP] eslint not installed. Install: npm install eslint"
      JS_COUNT="--"
    fi
  else
    echo "[SKIP] No eslint config found"
    JS_COUNT="--"
  fi
else
  echo "[SKIP] No .js/.ts files found"
  JS_COUNT=0
fi
```

### Ruby (rubocop, if present)

```bash
if [ "$HAS_RUBY" -eq 1 ]; then
  echo "=== RUBY (rubocop) ==="
  if command -v rubocop >/dev/null; then
    rubocop . 2>&1 | tee /tmp/lint-ruby.log
    RUBY_COUNT=$(grep -c "^" /tmp/lint-ruby.log || echo "0")
  else
    echo "[SKIP] rubocop not installed. Install: gem install rubocop"
    RUBY_COUNT="--"
  fi
else
  echo "[SKIP] No .rb files found"
  RUBY_COUNT=0
fi
```

## Step 3 — Aggregate and report

Collect findings from all linters. Render markdown summary:

```markdown
# Lint Report

| Language | Linter | Issues | Status |
|----------|--------|--------|--------|
| Bash | shellcheck | $BASH_COUNT | [INFO] |
| Python | pyflakes | $PYTHON_COUNT | [INFO] |
| JavaScript | eslint | $JS_COUNT | [INFO] |
| Ruby | rubocop | $RUBY_COUNT | [INFO] |

## Summary
- **Total issues detected:** <sum of all non-zero>
- **Passing linters:** <count>
- **Skipped (not installed):** <count>

## Next Steps

This is an informational audit. No blocking failures.

If issues found:
- **Fix manually:** `<linter> --fix` for auto-fixable issues
- **Or:** defer to development — linters often enforce style conventions that can be addressed during normal code review

No action required to proceed.
```

## Hard rules

- **Non-blocking.** Report only; do not fail or prevent workflow.
- **No automatic fixes.** User decides whether to fix linter warnings.
- **Graceful skip:** if linter not installed, skip that language (don't error).
- **Bash 3.2 compat:** all linting scripts must run on macOS Bash 3.2 (no `[[`, no bash 4+ features).
- **No file writes** except temp logs in `/tmp/`.
- **No questions asked.** Run and report.
