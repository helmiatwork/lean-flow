# plugin/agents/

# codemap.md — `plugin/agents/`

## Responsibility

This directory defines the lean-flow plugin's six specialized agents and the orchestrator's coordination logic. Each agent is a Claude system prompt (YAML frontmatter + markdown) that defines a narrow role, required skills, tools, and off-scope routing rules. Together they form a delegation framework that decomposes code tasks by expertise domain (implementation, design, review, search, research, architecture) to optimize for speed, cost, and quality.

## Design

**Agent contract pattern:** Each agent file follows a consistent structure:
- YAML frontmatter (`name`, `description`, `model`, `tools`)
- Role statement (who the agent is, what it does)
- Required Skills (superpowers or tool capabilities)
- Workflow section (entry points, decision rules, step-by-step execution)
- Rules (project-specific constraints, off-scope boundaries)
- Off-scope Routing table (when to dispatch to another agent, with exact re-dispatch format: `OFF-SCOPE: dispatch to <agent> — <brief>`)

**Delegation rules:**
- `fixer.md` — primary implementation (haiku, fast, cost-effective for concrete execution)
- `designer.md` — frontend/UI only (sonnet, uses project's actual CSS framework, never assumes Tailwind)
- `code-reviewer.md` — diff-level quality (sonnet, SOLID/patterns/coverage, separate from oracle)
- `oracle.md` — architecture decisions, security, complex debugging (sonnet think-only, **zero tools**, receives summaries only)
- `explorer.md` — codebase search, fast navigation (haiku, read-only, produces summaries for oracle)
- `librarian.md` — library/API research (haiku, WebSearch/WebFetch, current docs via Context7)
- `discuss.md` — pre-work scoping (gathers ambiguous decisions into multiple-choice options, locks scope before any implementation)
- `plan-plus-executor.md` — ephemeral step executor (inherits model, works on a single plan step in isolation, updates context files)
- `orchestrator.md` — session coordinator (opus, never writes code directly for medium/heavy, routes to agents, manages review loops)

## Flow

**Task dispatch sequence (medium/heavy task):**
1. User submits task → Orchestrator classifies (STAR: simple/medium/heavy/greenfield/hotfix)
2. Orchestrator runs `lean-flow:discuss` if scope is ambiguous → locks decisions with user
3. Orchestrator writes a structured plan with exact paths, commands, code snippets
4. Orchestrator dispatches `lean-flow:fixer` (haiku) with the plan
5. Fixer executes all steps, runs tests + linters, commits, pushes, creates PR
6. Fixer spawns `lean-flow:code-reviewer` (sonnet) for diff-level quality review
7. Fixer spawns `lean-flow:oracle` (sonnet, think-only) for architecture + security review
8. Oracle and code-reviewer return APPROVED or numbered issues; fixer applies fixes, loops until both APPROVED (hard cap: 3 combined rounds)
9. Fixer runs `cartographer.py changes` → dispatches `lean-flow:explorer` to fill affected `codemap.md` templates
10. Fixer merges PR once CI passes and oracle/code-reviewer approve

**Search/research
