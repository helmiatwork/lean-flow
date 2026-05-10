---
name: agents
description: List all lean-flow subagents with model, role, dispatch criteria, and tools.
---

# /lean-flow:agents

Reference command: display all available subagents in a structured table with dispatch guidance. Read-only. No questions, no writes.

## Step 1 — Read agent metadata

Read all agent definition files from `${CLAUDE_PLUGIN_ROOT}/plugin/agents/*.md`:
- `orchestrator.md`
- `fixer.md`
- `code-reviewer.md`
- `oracle.md`
- `designer.md`
- `explorer.md`
- `librarian.md`
- `discuss.md`
- `codemap.md`
- `plan-plus-executor.md`

Extract YAML frontmatter fields: `name`, `model`, `description`, `tools`.

## Step 2 — Build table

Render a 6-column markdown table:

| Agent | Model | Tools | Role | Dispatch when | Notes |
|-------|-------|-------|------|---------------|-------|
| orchestrator | opus | Coordination | Classify → plan → dispatch → verify. Never edits code for medium/heavy. | Session start, every user prompt | Main session only (not a subagent) |
| fixer | haiku | Read, Write, Edit, Bash, Grep, Glob, Agent | Code: features, fixes, refactors, tests, mechanical work. | After orchestrator plan approval. All impl, tests, commits, PR, reviews, merge. | End-to-end owner for medium/heavy/simple. 3 rounds cap on reviews. |
| code-reviewer | sonnet | Read-only | Code-quality, SOLID, patterns, coverage review. | After fixer opens PR. | Read-only: sonnet thinks, fixer applies. |
| oracle | sonnet | **None (think-only)** | Architecture, security, final review, decisions. | After code-reviewer, or complex diagnostics. | **Cannot read files or write code.** Explorer reads → orchestrator summarizes → oracle thinks. |
| designer | sonnet | Read, Write, Edit, Bash, Grep, Glob, Agent | UI/UX, frontend components, styling, interaction, a11y. | When step includes frontend work (parallel to fixer). | Commits to step branch; fixer owns PR cycle. |
| explorer | haiku | Read-only | File discovery, codebase navigation, cartography, diff scanning. | Post-commit (cartography), or when oracle needs context. | Read-only, cheap (haiku). Feeds diffs + file lists to oracle. |
| librarian | haiku | Context7 MCP, WebSearch, WebFetch | Docs lookup, API reference, web search, external research. | When task requires external knowledge. | No code writing; returns research summaries. |
| discuss | sonnet | None (text-only) | Async dialogue, alignment, scope clarification, feasibility discussion. | During planning when uncertainty is high. | Used pre-planning to validate assumptions. |
| codemap | sonnet | None (documentation focus) | Codebase structure documentation, module dependencies, architecture synthesis. | Heavy/greenfield planning phase. | Works with explorer to fill codemap.md. |
| plan-plus-executor | haiku | Agent, Bash, Read, Write, Edit | Plan execution driver: orchestrates step dispatch, tracks checkpoints. | Long multi-step sequences. | Deprecated; superpowers:executing-plans preferred. |

## Step 3 — Append legend

Render legend explaining special roles:

### Legend

**Orchestrator** — main Claude Code session, NOT a subagent. Acts under lean-flow:orchestrator contract (CLAUDE.md §1).

**Think-only agents** (`oracle`, `discuss`, `codemap`) — have `tools: []`. Cannot Read/Write/Edit/Bash. Return text guidance only. Orchestrator or fixer applies recommendations.

**Read-only agents** (`code-reviewer`, `explorer`, `librarian`) — have limited tools, no file editing. Return findings/summaries; fixer applies changes.

**Full agents** (`fixer`, `designer`) — have all tools (Read, Write, Edit, Bash, etc.). Implement code, commits, tests, PRs.

**Model routing:**
- **Opus** — main session (coordination only, never code for medium/heavy).
- **Sonnet** — reviewers (oracle, code-reviewer, designer). Expensive tokens on high-judgment tasks.
- **Haiku** — doers (fixer, explorer, librarian, plan-plus-executor). Fast, cheap, mechanical work.

**Dispatch rules:**
1. Orchestrator classifies task tier (STAR) and decides dispatch.
2. For medium/heavy: orchestrator plans (superpowers:writing-plans) then dispatches fixer.
3. Fixer executes fully: impl + tests + linters + commits + PR + reviews (code-reviewer + oracle) + merge.
4. Designer (optional): for frontend-heavy steps, dispatches in parallel. Commits to step branch; fixer owns final PR.
5. Oracle (complex diagnostics): triggered by fixer or orchestrator when architecture/security decisions needed, or after code-reviewer raises CHANGES_REQUESTED.
6. Explorer (post-commit cartography): haiku, cheap, fills `codemap.md` for changed folders.

**3-round review cap:**
- Code-reviewer + oracle combined may loop up to 3 rounds (fixer applies issues, re-runs tests + linters, pushes).
- Round 4+ → human escalation (post PR comment, stop looping).

**End-to-end contract (fixer, medium/heavy):**
1. Impl every step.
2. Tests ≥ 90% coverage.
3. Linters clean.
4. Commits (no Claude attribution).
5. Push.
6. Open PR.
7. Code-reviewer review + apply.
8. Oracle review + apply.
9. CI gate → merge.

### Design Philosophy

- **Cheap by default:** haiku agents do most work. Sonnet reserved for judgment (reviews, decisions).
- **Think-only oracle:** keeps expensive tokens minimal. Explorer does file I/O; oracle thinks.
- **No local re-dispatch:** subagents do NOT spawn other agents. Orchestrator orchestrates.
- **Designer ≠ PR owner:** designer commits to step branch; fixer always owns parent → main PR cycle (tests, linters, reviews, merge).

## Hard rules

- No file writes from this command.
- No questions asked.
- Table is reference only — do not re-implement dispatch logic here.
- Canonical dispatch rules live in `plugin/agents/orchestrator.md` and `plugin/agents/fixer.md`.
