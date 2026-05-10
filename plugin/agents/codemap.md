# plugin/agents/

# plugin/agents/ — Codemap

## Responsibility
Central registry of specialized AI agents in the lean-flow plugin. Each agent is a role-specific Claude persona with distinct capabilities, constraints, and routing rules. The orchestrator dispatches agents based on task classification and skill match.

## Design
**Agent structure:** Each `*.md` file defines one agent with frontmatter (name, description, model tier, tools) + system instructions. Agents are stateless — orchestrator holds session context and coordinates handoffs.

**Key patterns:**
- **Role isolation:** explorer (read-only search), fixer (code impl + tests), designer (UI/UX), code-reviewer (quality), oracle (think-only architect), librarian (docs), discuss (pre-scope), plan-plus-executor (single-step execution)
- **Tool constraints:** Each agent declares allowed tools (`tools: []` for oracle = no file access). Enforced by orchestrator dispatch, not by agent.
- **Routing protocol:** Off-scope tasks return `OFF-SCOPE: dispatch to <agent> — <brief>` for orchestrator to re-route.
- **Model tiers:** haiku (fast, cheap search/impl), sonnet (balanced, reviews), opus (orchestrator only)

## Flow
1. **Orchestrator** receives task, classifies tier (simple/medium/heavy), optionally dispatches `lean-flow:discuss` for scope alignment
2. **Discuss** surfaces 3–5 decision areas, user confirms choices, hands off to fixer/designer
3. **Fixer/Designer** execute plan steps, write tests, run linters, push commits
4. **Explorer** scans changed folders post-commit, fills `codemap.md` templates
5. **Code-Reviewer** (sonnet) checks diff-level quality, SOLID, coverage — parent→main PRs only
6. **Oracle** (sonnet, think-only) receives summaries from explorer/orchestrator, returns architecture verdict + PR approval
7. **Librarian** fetches docs on demand when fixer/orchestrator hits unfamiliar APIs
8. **Orchestrator** synthesizes feedback, loops until APPROVED, merges

## Integration
- **Orchestrator** (not in this folder) coordinates all agents via `Agent` tool, manages session state and PR lifecycle
- **CLAUDE.md** global rules override individual agent instructions; agents must read project's CLAUDE.md before starting
- **IssueRoutingRules** (in orchestrator context) map code-reviewer/oracle issues to fixer/designer for fixes
- **Codemap.md** (per folder) written by explorer, read by fixer/oracle for structure/patterns; feeds into `docs/CODEBASE_MAP.md` (Tier 1 synthesis)
- **GitHub API** via `gh` CLI: PR creation (fixer), review comments (code-reviewer, oracle), label/approval management (oracle)
