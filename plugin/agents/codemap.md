# plugin/agents/

# plugin/agents/ Codemap

## Responsibility
Defines the seven specialized agent types that execute different work patterns in the lean-flow plugin orchestrator. Each agent has a specific role (explorer, fixer, designer, discuss, librarian, oracle, plan-plus-executor), model tier, and tool set. The orchestrator dispatches tasks to agents based on work type and reads their instructions to determine when to call them.

## Design
- **Agent-as-markdown pattern:** Each agent is a self-contained `.md` file with YAML frontmatter (`name`, `description`, `model`, `tools`) followed by a role statement and detailed operational rules.
- **Tool scoping:** Each agent declares exactly which tools it can use (Read, Write, Edit, Bash, Grep, Glob, WebSearch, WebFetch, AskUserQuestion, Agent) — oracle intentionally has `tools: []` to enforce think-only constraint.
- **Model hierarchy:** Agents map to model tiers (haiku: explorer, fixer, librarian; sonnet: designer, discuss, oracle; inherit: plan-plus-executor).
- **Operational checklists:** Fixer includes a "Done Checklist" covering testing, security, DB/API safety, and async patterns; oracle includes a "Review Checklist" for PR validation; discuss includes a 6-step scoping workflow.

## Flow
1. **Orchestrator reads agent definitions** from `plugin/agents/` to determine capabilities and tool availability.
2. **Task dispatch:** Orchestrator selects agent based on work type — e.g., code exploration → explorer, feature implementation → fixer, architecture questions → oracle.
3. **Agent executes** using its declared tools and follows its role rules (never crossing tool boundaries).
4. **Results fed back** to orchestrator/user; oracle reviews flagged for post-approval codemap updates (Tier 2 always, Tier 1 if structural).

## Integration
- **Orchestrator:** Reads agent `.md` files to route tasks and validate tool usage.
- **Cartographer (codemap tooling):** Triggered by oracle's post-approval codemap flags; dispatches explorer to fill `codemap.md` templates, fixer to write updates.
- **Codebase structure:** Explorer uses `features.md` in directories as a navigation aid; agents assume project has design systems (Tailwind), test suites, and semantic HTML.
- **Feedback loop:** Fixer's "blockers" trigger oracle diagnosis; discuss's locked decisions feed into fixer's implementation scope.
