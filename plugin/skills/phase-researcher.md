---
name: phase-researcher
description: Research implementation patterns, pitfalls, and verified approaches before planning a complex task. Produces grounded guidance so plans aren't built on stale training data.
---

# lean-flow: phase-researcher

Answer: "What do I need to know to PLAN this well?" before touching a plan.

## When to invoke
After discuss confirms scope, before EnterPlanMode on medium/heavy tasks involving unfamiliar libraries, external APIs, or architecture decisions.

## Process

### Step 1 — Identify research questions
From the confirmed scope, extract 3–5 questions the plan depends on:
- "What's the current API for X in library Y version Z?"
- "What's the recommended pattern for doing X in this stack?"
- "What are the known pitfalls when implementing X?"
- "Does an existing solution exist we should use instead of building?"

### Step 2 — Parallel research
Dispatch parallel **librarian** agents (haiku) for each question:
- Use Context7 MCP for library APIs (highest trust)
- Use WebFetch for official docs
- Use WebSearch for ecosystem patterns and pitfalls
- Tag every finding: [VERIFIED: source] or [ASSUMED]

### Step 3 — Codebase scan
Dispatch **explorer** to scan the project for:
- Existing patterns that solve similar problems
- Libraries already in use (check package.json/requirements.txt)
- Established conventions to follow

### Step 4 — Synthesize findings

Output format:
---
## Research: [task description]

### Verified approach
[What to do, sourced from docs/official sources]
Source: [url or library]

### Existing project patterns
[What already exists in codebase that applies]
File: [path]

### Known pitfalls
- [pitfall] → [prevention]

### Don't hand-roll
[Things that seem custom but have good library solutions]

### Assumptions (LOW confidence — verify before planning)
- [assumption that needs confirmation]

---

## Rules
- Treat training knowledge as potentially stale — always verify
- Prefer Context7 > official docs > web search (trust order)
- If a question can't be answered with evidence, mark it ASSUMED
- Focus on what affects the PLAN, not implementation details
- Keep output under 400 tokens — planner needs signal, not noise
