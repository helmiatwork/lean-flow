---
name: discuss
description: Pre-work discussion skill. Analyzes a task, surfaces key decision areas as AI-recommended multiple choice options, and confirms scope before any implementation begins.
---

# lean-flow: discuss

Structured pre-work discussion. Identify the gray areas, present AI-recommended options, let the user decide.

## When invoked

You are about to start a medium or heavy task. Before writing any code or making any changes, run this discussion to lock in key decisions.

## Step 1 — Analyze

Read the user's request carefully. Identify **3–5 key decision areas** that would significantly affect implementation if left ambiguous. Focus on:
- Architecture or platform choices
- Scope boundaries (what's in vs. out)
- Tech stack or tooling preferences
- Data model or storage strategy
- User experience approach

Skip obvious decisions or things already stated in the prompt.

## Step 2 — Generate options

For each decision area:
1. Think through 2–4 realistic options
2. Pick the **best default** based on context (simplicity, common sense, stated constraints)
3. Write a 1-line rationale for your recommendation

## Step 3 — Present to user

Format exactly like this:

---
## Clarifying: [short task description]

Before starting, I need to lock in [N] decisions:

---
**1. [Decision area]**
*Recommended: **[letter]) [option]** — [1-line rationale]*
a) [Option A]  b) [Option B]  c) [Option C]

**2. [Decision area]**
*Recommended: **[letter]) [option]** — [1-line rationale]*
a) [Option A]  b) [Option B]

*(repeat for each area)*

---
Reply with your choices (e.g. `1a 2b 3c`) or `yes` to accept all recommended defaults.

---

## Step 4 — Capture choices

Parse the user's reply:
- `yes` → accept all recommended defaults
- `1a 2b 3c` → map each to the selected option
- Partial reply (e.g. `1b`) → accept defaults for unspecified areas

## Step 5 — Confirm and summarize

Show a compact decision summary:

---
## Decisions locked ✓

1. [Decision area]: **[chosen option]**
2. [Decision area]: **[chosen option]**
3. [Decision area]: **[chosen option]**

Ready to proceed. Confirm with `yes` or adjust any decision.

---

## Step 6 — Hand off

Once the user confirms, say:
> "Scope confirmed. Proceeding."

Then stop — the orchestrator continues with the actual implementation.

## Rules
- Never start implementation during this skill
- Never ask open-ended questions — always present options
- Keep each option label short (3–6 words max)
- Rationale must be 1 line, specific to this task's context (not generic)
- If the user's prompt already answers a decision area, skip it
- Max 5 decision areas — don't over-question simple tasks
