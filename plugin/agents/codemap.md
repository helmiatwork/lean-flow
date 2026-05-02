# plugin/agents/

# plugin/agents/ — Codemap

## Responsibility

Defines nine specialized agent roles for the lean-flow plugin. Each agent is a Claude model variant with specific tools, skills, and guardrails designed to handle one task category efficiently:
- **Discuss** — pre-work scoping and decision capture
- **Explorer** — fast codebase search and cartography
- **Librarian** — external API/library research
- **Fixer** — primary implementation and merge-to-main owner
- **Designer** — frontend polish and component work
- **Code-Reviewer** — diff-level quality, SOLID, coverage
- **Oracle** — architecture decisions and think-only review
- **Plan-Plus-Executor** — single-step execution from structured plans
- **Orchestrator** — meta-reference for main session behavior

## Design

Each agent is a markdown file with YAML frontmatter + role description. Pattern:
- `name` — agent identifier (used in `@lean-flow:name` dispatch syntax)
- `description` — one-liner trigger condition
- `model` — inherit, haiku, sonnet, or opus; `inherit` → orchestrator's model
- `tools: []` — explicit tool list; oracle has `[]` (think-only), fixer has `["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Agent"]`
- Skills section lists required superpowers in mandatory order
- Role + Rules sections define behavior, guardrails, and decision trees

**Key design choice:** Oracle and Code-Reviewer are separated — oracle handles architecture/debugging (think-only, broad), code-reviewer handles diff quality/patterns/coverage (read-only, focused on PRs). Fixer owns end-to-end execution chain including dispatch of both reviewers and application of feedback.

## Flow

Orchestrator classifies user prompt → selects agent(s) via STAR dispatcher:
1. **Simple** — orchestrator edits directly
2. **Medium/Heavy** — orchestrator writes plan → dispatches `fixer` (haiku) with exact steps
3. **Discovery** — orchestrator dispatches `explorer` or `librarian` in parallel, receives summaries
4. **Ambiguous scope** — orchestrator dispatches `discuss` first to lock decisions
5. **PR review** — fixer dispatch → code-reviewer (sonnet) → oracle (sonnet, think-only) → fixer applies feedback → CI/merge

Plan-Plus-Executor is a ephemeral agent used only within plan-plus structured workflows — reads context files, executes one step, updates context/, reports back. Does not persist in the main conversation.

## Integration

- **Orchestrator** (main session) reads all agent files at startup; uses agent names in `@lean-flow:name` dispatch syntax
- **Fixer** (haiku, primary worker) invokes `code-reviewer` and `oracle` as sub-agents via Agent tool, routes their issues per IssueRoutingRules, applies fixes
- **Explorer** (haiku, scanner) is dispatched by orchestrator for codebase map builds; after fixer commits, orchestrator runs `git diff` and dispatches explorer to fill `codemap.md` per changed folders
- **Librarian** (haiku, research) is deployed by orchestrator/fixer when library APIs are uncertain
- **Designer** (sonnet, UI) is dispatched for frontend-heavy tasks; does not open PRs — fixer takes over for merge
- **
