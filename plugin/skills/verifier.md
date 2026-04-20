---
name: verifier
description: Goal-backward verification after execution. Checks that the codebase actually delivers what was promised — not just that tasks were completed. Catches stubs, disconnected components, and hollow implementations.
---

# lean-flow: verifier

Answer: "Did we actually build what we said we'd build?" — not "Did we check all the boxes?"

## When to invoke
After all steps are merged into the parent branch, before the final oracle security audit.

## The core distinction
A task "create auth endpoint" can be marked done while password hashing is missing. Task completion ≠ goal achievement.

## 4-Level artifact verification
For each deliverable, verify:
1. **Exists** — File is present in codebase
2. **Substantive** — Contains real implementation (not stub, placeholder, TODO, empty return)
3. **Wired** — Imported and used by other components (not created in isolation)
4. **Data-flowing** — Receives real data (not hardcoded empty values, not mocked in production code)

## Process

### Step 1 — Extract must-haves
From the original confirmed task/scope, list observable truths that must hold:
- User-facing behaviors ("user can log in with email+password")
- Artifacts ("auth middleware exists and is applied to protected routes")
- Key connections ("new component is imported in App.tsx")

### Step 2 — Dispatch explorer
For each must-have, dispatch **explorer** to:
- Locate the relevant files
- Check for stub indicators: `TODO`, `throw new Error('not implemented')`, `return null`, `return []`, hardcoded test data in production paths
- Verify imports/wiring: grep for usage of the new component/function
- Check data flows: is real data passed in, or is it always empty/mocked?

### Step 3 — Run anti-pattern scan
Explorer scans the changed files for:
- `// TODO` or `// FIXME` in implementation (not test) files
- Empty function bodies or `return undefined/null` in non-trivial functions
- Hardcoded values where dynamic data is expected
- New files never imported anywhere

### Step 4 — Output verification report

```
## Verification: [task description]

### ✅ Verified
- [must-have]: exists + substantive + wired + data-flowing ✓

### ⚠️ Gaps found
- [must-have]: exists ✓ | substantive ✓ | wired ❌ — [file] is never imported
- [must-have]: exists ✓ | substantive ❌ — contains TODO at line 42

### 🔍 Needs human verification
- [must-have]: cannot verify programmatically (visual behavior, real-time dynamics)

### Status: PASSED / GAPS FOUND / HUMAN NEEDED
```

### Step 5 — On gaps found
Dispatch **fixer** to close each gap. Re-run verifier after fixes.

## Rules
- Never trust task checkboxes — verify actual code
- Wiring check is mandatory — most hollow implementations hide in disconnected pieces
- Do NOT modify implementation while verifying — flag gaps, let fixer fix them
- If uncertain, flag for human verification rather than assuming pass
