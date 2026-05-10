---
name: sync-checklist
description: Manual force-run plan checklist sync hook (user-driven explicit marking).
---

# /lean-flow:sync-checklist

Manual plan checklist checkpoint marking. Allows user to explicitly mark plan steps as complete (overrides auto-detection heuristic). Requires explicit user confirmation per step.

## Step 1 — Detect plan files

Scan repo for plan files:

```bash
PLANS_FOUND=$(find .plans .planning -type f \( -name "plan-full.md" -o -name "PLAN.md" \) 2>/dev/null)

if [ -z "$PLANS_FOUND" ]; then
  echo "ℹ️ No plan files found."
  echo "   Checked: .plans/*/plan-full.md, .planning/*/PLAN.md"
  exit 0
fi
```

## Step 2 — List plans and their checkboxes

For each plan file found, count checkbox items:

```bash
echo "=== Plan Files Found ==="
echo ""

for PLAN_FILE in $PLANS_FOUND; do
  PLAN_NAME=$(basename $(dirname "$PLAN_FILE"))
  TOTAL_BOXES=$(grep -c "^- \[" "$PLAN_FILE" || echo "0")
  COMPLETED_BOXES=$(grep -c "^- \[x\]" "$PLAN_FILE" || echo "0")
  PENDING_BOXES=$((TOTAL_BOXES - COMPLETED_BOXES))
  
  echo "Plan: $PLAN_NAME (file: $PLAN_FILE)"
  echo "  Total checkboxes: $TOTAL_BOXES"
  echo "  Completed: $COMPLETED_BOXES"
  echo "  Pending: $PENDING_BOXES"
  echo ""
done
```

## Step 3 — Ask user: which step to mark

Display AskUserQuestion with options:

```
Which plan step to mark complete?

Format: <plan-name> step <N>
Example: user-auth step 2

Plans available:
  - user-auth (3 steps, 1 completed, 2 pending)
  - data-sync (5 steps, 2 completed, 3 pending)

Enter plan and step (or 'cancel'):
```

Parse user input: `<plan-name> step <N>`

Validate:
- Plan exists
- Step number exists and is in pending state (checkbox is `[ ]`)
- If validation fails, show error and re-ask

## Step 4 — Mark step as complete

Once user confirms, edit plan file:

```bash
PLAN_FILE=".plans/$PLAN_NAME/plan-full.md"
STEP_NUM=$N

# Count from top, find Nth checkbox with "[ ]"
# Replace that specific checkbox with "[x]"

# Use sed to find and replace (must be robust)
# Strategy: number all checkboxes, find Nth pending, replace it
```

Use `Edit` tool to replace the exact checkbox:

```
OLD: "- [ ] <step-N-text>"
NEW: "- [x] <step-N-text>"
```

## Step 5 — Commit mark

Create atomic commit:

```bash
git add "$PLAN_FILE"
git commit -m "chore: mark plan-$PLAN_NAME step-$N complete"
```

Render confirmation:

```markdown
✅ Plan checkpoint marked

| Plan | Step | Status |
|------|------|--------|
| $PLAN_NAME | $N | [x] Complete |

Commit: $(git rev-parse --short HEAD)

Next: Continue with next step or push + open PR.
```

## Step 6 — Offer next action

Ask user:

```
Done! Options:
  [1] Mark another step
  [2] Push changes
  [3] Done (exit)

Choose [1], [2], or [3] (default: 3):
```

**If [1]:** loop back to Step 3

**If [2]:** `git push origin <branch>` and show success

**If [3]:** exit cleanly

## Hard rules

- **Explicit user confirm required.** No auto-heuristics; user must explicitly say "mark step N".
- **One step at a time.** User explicitly chooses which plan + which step each time.
- **Atomic commits.** One step = one commit.
- **No auto-sync.** This command is manual override only; Layer 3 hook auto-detect is separate (opt-in via env var).
- **Robust checkbox matching.** Use exact `- [ ]` and `- [x]` format (no variations).
- **Idempotent.** Marking same step twice is no-op (already marked).
- **No push by default.** User explicitly chooses [2] to push.
