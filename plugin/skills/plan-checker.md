---
name: plan-checker
description: Verify a plan will achieve its goal before execution. Goal-backward analysis across 8 dimensions — catches gaps before fixer wastes tokens on a broken plan.
---

# lean-flow: plan-checker

Verify plans before execution. A task list that looks complete can still miss the goal entirely.

## When to invoke
After ExitPlanMode, before dispatching fixer. Orchestrator runs this on the plan-plus skeleton.

## Input
The plan content (from plan-plus skeleton file or described in conversation).

## 8 Verification Dimensions

### 1. Goal Coverage
Every stated requirement has at least one covering task. No requirement left floating.

### 2. Task Completeness
Each task specifies: what file(s), what action, how to verify it worked.

### 3. Dependency Order
Tasks are sequenced correctly. No task requires output from a later task.

### 4. Integration Wiring
Artifacts are connected — a new component is imported/used, not just created in isolation.

### 5. Scope Sanity
Plan stays within what was confirmed in discussion. No scope creep, no silent reductions.

### 6. Verification Presence
Each task has a way to confirm it worked (test, observable output, endpoint response).

### 7. Decision Consistency
Plan matches confirmed decisions from the discuss phase. No contradictions.

### 8. Pattern Alignment
New files follow existing project patterns (dispatch explorer to check if needed).

## Red Flags → BLOCKER

- Any requirement with zero covering tasks
- Task with no verify step
- Circular dependencies
- New component created but never imported/used
- Plan contradicts a confirmed discussion decision
- "v1 / simplified / static for now" language hiding scope reduction

## Output Format

**If PASSED:**
```
✅ Plan verified — 8/8 dimensions passed
Ready to execute.
[brief summary table of requirements → tasks coverage]
```

**If ISSUES FOUND:**
```
⛔ BLOCKER: [dimension] — [description] — Fix: [hint]
⚠️  WARNING: [dimension] — [description] — Fix: [hint]
ℹ️  INFO: [dimension] — [suggestion]
```

## Rules
- Work backward from the goal, not forward from the task list
- A task that exists but doesn't wire up doesn't count as coverage
- Scope reduction language is always a BLOCKER, never a WARNING
- If plan is short (1-2 tasks), skip dimensions 3 and 9 — not applicable
