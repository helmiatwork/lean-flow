# plugin/agents/

# codemap.md — `plugin/agents/`

## Responsibility

The agents directory defines the lean-flow plugin's specialist agents—each with a specific role in the development workflow. Each `.md` file declares an agent's name, description, model, tools, required skills, and behavioral rules. The orchestrator (main session) reads these definitions to classify tasks and dispatch appropriate agents.

## Design

**Agent Pattern**: Each file follows a YAML frontmatter + Markdown body structure:
- `name:` — agent identifier (e.g., `code-reviewer`, `fixer`)
- `description:` — 1-2 sentence when-to-use guidance
- `model:` — LLM choice (`haiku`, `sonnet`, `opus`, or `inherit`)
- `tools:` — list of enabled MCP tools (e.g., `["Read", "Write", "Agent"]`); empty `[]` means think-only (oracle)
- `superpowers:` (optional) — skill dependencies declared in role sections

**Key Distinctions**:
- **fixer** (haiku) — executes plans end-to-end; owns impl + tests + PR chain
- **oracle** (sonnet, `tools: []`) — think-only architect; never reads files directly, receives summaries
- **code-reviewer** (sonnet, read-only) — diff-level quality review; SOLID + patterns + coverage
- **designer** (sonnet) — UI/UX specialist; stops before PR (fixer takes over)
- **explorer** (haiku, read-only) — parallel search; finds files, populates codemaps
- **librarian** (haiku, read-only) — docs/API lookup; WebSearch + WebFetch
- **discuss** (sonnet, stateless) — pre-work scoping; surfaces decisions, captures user choices, stops before impl
- **plan-plus-executor** (ephemeral context) — executes single plan steps with isolated context files

## Flow

**Dispatch chain** (medium/heavy task):
1. Orchestrator classifies task → calls `discuss` if ambiguous (scope alignment)
2. Orchestrator writes detailed plan → dispatches **fixer** with full contract
3. Fixer implements all steps, runs tests/linters, commits, pushes branch
4. Fixer creates PR → spawns **code-reviewer** (haiku plan exists; use sonnet for actual review)
5. Code-reviewer issues returned → fixer routes to self or **designer** (IssueRoutingRules)
6. Fixer re-tests/re-lints, pushes fixes → PR updated
7. Fixer spawns **oracle** (sonnet, think-only) with diff summary from **explorer**
8. Oracle returns `APPROVED` or issues → loop steps 5–7 (max 3 rounds combined)
9. Fixer runs `cartographer.py`, dispatches **explorer** to fill affected codemaps
10. Fixer merges once CI green + oracle approved

**Designer flow** (UI/UX tasks):
- Orchestrator dispatches **designer** with impl steps
- Designer implements + tests (≥90% coverage), commits, pushes
- Designer **stops** — fixer takes the branch, opens PR, routes reviews

## Integration

- **orchestrator.md** (not in this dir; main session) — reads all agents/ definitions, routes tasks via dispatch rules
- **Agents call each other via `Agent
