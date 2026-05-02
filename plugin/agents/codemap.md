# plugin/agents/

# codemap.md – `plugin/agents/`

## Responsibility
Defines the lean-flow plugin's six specialist agents (code-reviewer, designer, discuss, explorer, fixer, librarian, oracle) and one meta-agent (orchestrator). Each agent is a Claude model + tool set + contract, dispatched by the orchestrator for specific task types. This directory is the **agent library** — a reference for orchestrator routing rules and agent capabilities.

## Design
**Agent-as-contract pattern**: Each `.md` file declares a single agent with:
- **model** (haiku/sonnet/opus) — inference cost and reasoning depth
- **tools** (Read, Write, Bash, Grep, Agent, WebSearch, etc.) — what the agent can do
- **skills** (superpowers) — what the agent is trained to do
- **off-scope routing table** — where to send work that doesn't match this agent's contract
- **hard constraints** (e.g., oracle's `tools: []`, fixer's PR review loop cap of 3 rounds)

Key patterns:
- **Think-only (oracle)**: No file tools—receives summaries from orchestrator/explorer, synthesizes decisions
- **Read-only (explorer, librarian)**: Can search/fetch but never edit—provide summaries for think agents
- **Full-stack (fixer, designer)**: Can plan, execute, test, PR, dispatch reviewers, loop until APPROVED
- **Pre-work (discuss)**: Structured scoping via multiple-choice, locks decisions before execution

## Flow
1. **Orchestrator classifies** prompt (simple/medium/heavy)
2. **For medium/heavy**: Orchestrator → `lean-flow:discuss` (optional, if ambiguous) → locks decisions
3. **Orchestrator writes plan** with exact code paths, commands, files
4. **Orchestrator dispatches**:
   - `lean-flow:explorer` (haiku) for unknowns/diffs (parallel, cheap)
   - `lean-flow:librarian` (haiku) for API/docs (parallel, cheap)
   - `lean-flow:fixer` (haiku) for impl + tests + commits + PR + code-reviewer + oracle loops
   - `lean-flow:designer` (sonnet) for UI/UX impl (similar loop to fixer)
5. **Fixer/designer complete**, dispatch `lean-flow:code-reviewer` (sonnet) + `lean-flow:oracle` (sonnet, think-only)
6. **Oracle** synthesizes architecture decision, returns APPROVED or numbered issues
7. **Fixer/designer** apply fixes, re-run tests/linters, push, loop until both APPROVED (max 3 rounds)
8. **Post-approval**: Explorer fills codemaps, fixer writes updates, CI gates, merge

## Integration
- **Orchestrator** reads agent contracts from this directory to build routing tables and capability lookups
- **Fixer/designer** invoke subagents (code-reviewer, oracle, explorer, librarian) via `tools: ["Agent"]`
- **Oracle** receives summaries (not files) from explorer/orchestrator—synthesizes without reading
- **Explorer** scans diffs post-commit → fills `codemap.md` templates in target directories
- **Agent off-scope tables** form a closed dispatch graph—every off-scope task routes to exactly one other agent, preventing routing loops
