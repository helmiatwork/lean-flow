---
name: map-codebase
description: Deep codebase analysis using parallel explorer agents. Produces 7 structured documents covering stack, architecture, structure, integrations, conventions, testing, and concerns. Use on brownfield projects before starting significant work.
---

# lean-flow: map-codebase

Understand before building. Spawns parallel explorer agents to map an unfamiliar or complex codebase across 7 dimensions.

## When to invoke
- Brownfield projects before planning significant features
- After joining an existing codebase
- Before large refactors to understand current state
- When session-briefing context feels insufficient

## Process

### Step 1 — Scope confirmation
Confirm with user: root path to analyze, any directories to skip (node_modules, .git, build/ are always skipped).

### Step 2 — Parallel analysis
Spawn 4 parallel **explorer** agents, each with a focus area:

**Agent 1 — Tech focus:**
Produces `STACK.md` and `INTEGRATIONS.md`
- Languages, frameworks, runtime versions (from package.json, pyproject.toml, etc.)
- All external dependencies and what they're used for
- External APIs, services, databases connected
- Auth providers, payment processors, analytics

**Agent 2 — Architecture focus:**
Produces `ARCHITECTURE.md` and `STRUCTURE.md`
- System design: monolith/microservices/serverless
- Data flow: how data moves between components
- Directory structure with purpose of each major folder
- Entry points, key modules, public APIs

**Agent 3 — Quality focus:**
Produces `CONVENTIONS.md` and `TESTING.md`
- Naming conventions, file organization patterns
- Code style patterns (found in actual code, not just config)
- Test framework, test coverage, test patterns used
- CI/CD setup, linting, formatting tools

**Agent 4 — Concerns focus:**
Produces `CONCERNS.md`
- TODOs and FIXMEs in codebase (with file locations)
- Outdated dependencies or deprecated patterns
- Security concerns (hardcoded secrets, missing validation)
- Performance hotspots (N+1 queries, large files, missing indexes)
- Technical debt areas

### Step 3 — Collect and surface
Orchestrator collects all 7 document summaries from agents. Each explorer writes directly to context — no intermediate files needed (unlike GSD which uses .planning/).

### Step 4 — Output
Present structured summary to user:
```
## Codebase Map: [repo name]

### Stack
[key findings from STACK.md]

### Architecture
[key findings from ARCHITECTURE.md]

### Conventions
[key findings from CONVENTIONS.md]

### Test coverage
[key findings from TESTING.md]

### ⚠️ Concerns
[key findings from CONCERNS.md]

### Integrations
[key findings from INTEGRATIONS.md]
```

Ask: "Anything here that looks outdated or that I should know before starting?"

## Rules
- Token-efficient: use explorer (haiku), not oracle (sonnet)
- Skip binary files, build artifacts, and generated code
- Focus on patterns in actual code, not just config files
- Concerns section is mandatory — always look for problems
- Don't generate implementation recommendations — this is observation only
