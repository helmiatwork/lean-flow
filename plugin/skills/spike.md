---
name: spike
description: Throwaway experiment to validate feasibility before planning. Each spike answers one specific question with observable evidence. Use before planning anything with unclear technical risk.
---

# lean-flow: spike

Validate before committing. A 15-minute spike prevents a 3-hour wrong implementation.

## When to invoke
When assumptions-analyzer flags an UNCLEAR assumption, or when the feasibility of a technical approach is unknown before planning.

## Input
A specific question to answer: "Can X work in this environment?" or "Is approach Y viable for our stack?"

## Process

### Step 1 — Frame the question
Clarify exactly what the spike must answer. One question only. Examples:
- "Does Stripe webhook validation work with our Express middleware setup?"
- "Can SQLite handle concurrent writes at our expected load?"
- "Does the existing auth token format support the new permissions we need?"

### Step 2 — Plan the experiment
Define the minimal experiment:
- What to build (throwaway, under 50 lines)
- What observable output confirms success/failure
- Time box: 15 minutes of fixer time max

### Step 3 — Execute (fixer)
Dispatch **fixer** to:
- Create spike file(s) in a clearly named temp location (e.g. `spike-[topic].ts`)
- Implement the minimal experiment
- Run it and capture output

### Step 4 — Evaluate result
Compare output against the success criteria from Step 2.

**Result format:**
---
## Spike: [question]

**Verdict: ✅ VIABLE / ❌ NOT VIABLE / ⚠️ VIABLE WITH CAVEATS**

**Evidence:**
[what was run, what output was produced]

**Implication for plan:**
[what this means — proceed as planned / use approach B / add constraint X]

**Spike files:** [list — to be deleted before shipping]
---

### Step 5 — Clean up
If spike was successful: note the approach, delete spike files before final commit.
If spike failed: recommend alternative approach, do NOT proceed with original plan.

## Rules
- One question per spike — don't let it expand
- Spike files must be cleaned up before any PR
- A passing spike is not implementation — it's a green light to plan
- If spike takes more than 30 min of fixer time, stop and escalate to oracle
