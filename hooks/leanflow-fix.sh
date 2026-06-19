#!/usr/bin/env bash
# lean-flow-fix.sh — idempotent bootstrap that repairs lean-flow plugin defects
# after a fresh install or version bump. Safe to run repeatedly.
#
# Repairs:
#   1. Missing workflows/claude-rules.md (referenced by load-workflow.sh)
#   2. Dangling skill refs in systematic-debugging.md and test-driven-development.md
#
# Idempotency:
#   - Per-version marker at ~/.claude/.lean-flow-fix-applied.<plugin-hash>
#   - sed patches use distinctive sentinels so repeat runs are no-ops
#
# Usage: bash ~/.claude/scripts/lean-flow-fix.sh

set -u
LEAN_ROOT="$HOME/.claude/plugins/cache/lean-flow/lean-flow"

if [ ! -d "$LEAN_ROOT" ]; then
  echo "[lean-flow-fix] lean-flow not installed at $LEAN_ROOT — nothing to do"
  exit 0
fi

# Find versioned plugin dirs (e.g., 70e255d119af)
shopt -s nullglob 2>/dev/null || true
fixed_any=0
for VERSION_DIR in "$LEAN_ROOT"/*/; do
  [ -d "$VERSION_DIR/skills" ] || continue
  VERSION_HASH=$(basename "$VERSION_DIR")
  MARKER="$HOME/.claude/.lean-flow-fix-applied.${VERSION_HASH}"

  if [ -f "$MARKER" ]; then
    echo "[lean-flow-fix] already applied for version $VERSION_HASH (skip)"
    continue
  fi

  echo "[lean-flow-fix] applying fixes to $VERSION_HASH..."

  # ── 1. workflows/claude-rules.md ────────────────────────────────────
  WF_DIR="$LEAN_ROOT/workflows"
  WF_FILE="$WF_DIR/claude-rules.md"
  if [ ! -f "$WF_FILE" ]; then
    mkdir -p "$WF_DIR"
    cat > "$WF_FILE" <<'CLAUDE_RULES_EOF'
# Lean-Flow Canonical Rules

These rules govern routing for any non-trivial task. Injected on every UserPromptSubmit by load-workflow.sh.

## Task classification
| Type | Path |
|------|------|
| Simple | @fixer direct → done checklist → commit |
| Medium | STAR → discuss → research → superpowers:writing-plans → superpowers:executing-plans |
| Heavy | STAR → discuss → map-codebase + ingest-docs → research → superpowers:writing-plans → superpowers:executing-plans |
| Hotfix | @fixer minimal fix → @oracle review → PR to main |
| Bug | superpowers:systematic-debugging FIRST |

## Skill triggers
- Bug → superpowers:systematic-debugging
- Code-create → superpowers:test-driven-development
- Done? → superpowers:verification-before-completion
- Plan medium/heavy → superpowers:writing-plans
- Execute plan → superpowers:executing-plans
- Parallel agents → superpowers:dispatching-parallel-agents
- PR feedback → superpowers:receiving-code-review
- Final merge → superpowers:finishing-a-development-branch

## Hard rules
1. Never write code before classifying.
2. Bugs → systematic-debugging first.
3. Features → TDD (failing test first).
4. Done claims need evidence (verification-before-completion).
5. Planning medium/heavy → superpowers:writing-plans (replaces plan-plus).
6. 3 fixer failures → @oracle.
7. @oracle never writes code.
CLAUDE_RULES_EOF
    echo "  ✓ wrote $WF_FILE"
  else
    echo "  · $WF_FILE already exists"
  fi

  # ── 2. systematic-debugging.md skill refs ──────────────────────────
  SD="$VERSION_DIR/skills/systematic-debugging.md"
  if [ -f "$SD" ]; then
    if /usr/bin/grep -q 'See `root-cause-tracing.md` in this directory' "$SD" 2>/dev/null; then
      /usr/bin/sed -i.bak 's|See `root-cause-tracing\.md` in this directory for the complete backward tracing technique\.|See `superpowers:systematic-debugging` (Phase 2 — backward tracing) for the complete technique. The local `root-cause-tracing.md` was retired in favor of the superpowers methodology.|' "$SD"
      rm -f "${SD}.bak"
      echo "  ✓ patched root-cause-tracing ref in systematic-debugging.md"
    fi
    if /usr/bin/grep -q '^- \*\*`root-cause-tracing\.md`\*\*' "$SD" 2>/dev/null; then
      # Replace the 3-line bullet block with redirect block
      /usr/bin/sed -i.bak '/^- \*\*`root-cause-tracing\.md`\*\*/,/^- \*\*`condition-based-waiting\.md`\*\*/c\
- **Root-cause tracing** — `superpowers:systematic-debugging` Phase 2\
- **Defense in depth** — `superpowers:systematic-debugging` (post-fix hardening)\
- **Condition-based waiting** — `superpowers:systematic-debugging` (timing/race conditions)
' "$SD"
      rm -f "${SD}.bak"
      echo "  ✓ patched supporting-techniques block"
    fi
  fi

  # ── 2b. load-workflow.sh header (remove plan-plus reference) ──────
  LW="$VERSION_DIR/scripts/load-workflow.sh"
  if [ -f "$LW" ]; then
    if /usr/bin/grep -q 'lean-flow:fixer with plan-plus skill' "$LW" 2>/dev/null; then
      /usr/bin/sed -i.bak 's|- Planning → lean-flow:fixer with plan-plus skill (NOT /gsd-plan-phase)|- Planning (medium/heavy) → superpowers:writing-plans (plan-plus is deprecated)|' "$LW"
      /usr/bin/sed -i.bak 's|- Execution → lean-flow:fixer (NOT /gsd-executor)|- Execution → superpowers:executing-plans + lean-flow:fixer (NOT /gsd-executor)|' "$LW"
      /usr/bin/sed -i.bak 's|- Verification → lean-flow:verifier (NOT /gsd-verify-phase)|- Verification → superpowers:verification-before-completion + lean-flow:verifier (NOT /gsd-verify-phase)|' "$LW"
      rm -f "${LW}.bak"
      echo "  ✓ patched load-workflow.sh header to use superpowers"
    fi
  fi

  # ── 3. test-driven-development.md skill ref ────────────────────────
  TDD="$VERSION_DIR/skills/test-driven-development.md"
  if [ -f "$TDD" ]; then
    if /usr/bin/grep -q '@testing-anti-patterns\.md' "$TDD" 2>/dev/null; then
      /usr/bin/sed -i.bak 's|read @testing-anti-patterns\.md to avoid common pitfalls:|see `superpowers:test-driven-development` (anti-patterns section) — the local `testing-anti-patterns.md` was retired. Common pitfalls to avoid:|' "$TDD"
      rm -f "${TDD}.bak"
      echo "  ✓ patched testing-anti-patterns ref in test-driven-development.md"
    fi
  fi

  touch "$MARKER"
  fixed_any=1
done

if [ "$fixed_any" -eq 0 ]; then
  echo "[lean-flow-fix] all detected versions already patched"
fi

exit 0
