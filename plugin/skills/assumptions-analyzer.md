---
name: assumptions-analyzer
description: Scan codebase for evidence behind every plan assumption before execution. Produces structured assumptions with file citations and confidence levels to prevent mid-execution surprises.
---

# lean-flow: assumptions-analyzer

Analyze codebase evidence for a planned task. Surface what's assumed vs. what's proven before fixer burns tokens on a wrong plan.

## When to invoke
Before EnterPlanMode on complex or heavy tasks. The orchestrator invokes this after discuss confirms scope.

## Process

### Step 1 — Extract assumptions
From the confirmed task/scope, list every implicit assumption the plan would rely on:
- Existing code structure assumptions ("auth middleware exists", "DB schema has X column")
- Dependency assumptions ("library X is installed", "API endpoint returns Y shape")
- Pattern assumptions ("we use repository pattern", "tests use Jest")
- State assumptions ("migrations are up to date", "env vars are set")

### Step 2 — Dispatch explorer
For each assumption, dispatch an **explorer** (haiku) to find codebase evidence:
- Search for relevant files, grep for patterns, check package.json, read key files
- Explorer returns: file path citations + what it found (or didn't find)

### Step 3 — Classify confidence
Rate each assumption:
- **Confident** — Direct evidence found (file exists, pattern confirmed, dependency present)
- **Likely** — Indirect evidence (convention suggests it, similar patterns found)
- **Unclear** — No evidence found, or contradicting evidence

### Step 4 — Output structured report

Format:
---
## Assumptions Analysis

### [Area 1: e.g. Data Layer]
| Assumption | Evidence | File | Confidence |
|------------|----------|------|------------|
| [statement] | [what was found] | [path] | Confident/Likely/Unclear |

### [Area 2: e.g. Auth]
...

### ⚠️ Unclear assumptions requiring resolution:
- [assumption] — [what's missing, what to verify]

---

### Step 5 — Flag blockers
If any Unclear assumption would fundamentally break the plan, flag it as a **BLOCKER** and recommend either:
a) A quick spike to verify (invoke `lean-flow:spike`)
b) An updated plan that doesn't rely on the unclear assumption

## Rules
- Only cite files that actually exist (explorer must verify)
- Never speculate — if evidence is absent, say so
- Skip obvious assumptions (e.g. "git is installed")
- Max 4 areas, 4 assumptions each
