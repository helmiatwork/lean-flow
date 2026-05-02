# plugin/agents/

# plugin/agents/ Codemap

## Responsibility
Defines the lean-flow plugin's specialist agents and their roles in the orchestration system. Each `.md` file is an agent specification that describes a single agent's purpose, required skills, tools, constraints, and operational rules. The folder serves as the canonical reference for agent behavior and dispatch decisions.

## Design
- **Agent-as-markdown pattern**: Each agent is a standalone `.md` file with YAML frontmatter (`name`, `description`, `model`, `tools`) and markdown role/rules sections
- **Skill-based capability declaration**: Agents declare required superpowers (e.g., `superpowers:executing-plans`, `superpowers:test-driven-development`) that orchestrator validates before dispatch
- **Think-only vs read-write separation**: Oracle is pure think (`tools: []`); explorer/librarian are read-only; fixer/designer are full read-write; orchestrator coordinates
- **Tiered specialization**: Each agent is optimized for cost/speed in its domain (haiku for search/read, sonnet for review/architecture, inherited/opus for execution)

## Flow
1. **Orchestrator classifies** user request → STAR tier (simple/medium/heavy/greenfield/hotfix)
2. **Dispatch decision**: Simple work stays in orchestrator; medium/heavy delegates to `lean-flow:fixer`
3. **Supporting agents** called on-demand: `explorer` for codebase scans, `librarian` for docs, `oracle` for architecture, `code-reviewer` for quality, `designer` for UI/UX
4. **Fixer end-to-end flow**: implement → test → lint → commit → PR → dispatch `code-reviewer` + `oracle` → apply feedback loops (max 3 rounds) → merge
5. **Post-merge**: `explorer` fills `codemap.md` per changed folders; `oracle` decides if Tier 1 updates needed

## Integration
- **Orchestrator** (orchestrator.md) references all agents and decides when to dispatch each
- **Fixer** (fixer.md) is the primary executor; spawns `code-reviewer` and `oracle` agents
- **Code-reviewer** (code-reviewer.md) validates implementation against plan and standards before merge
- **Oracle** (oracle.md) provides architecture/security review, synthesizes explorer scans into codemaps, decides codemap updates
- **Explorer** (explorer.md) scans diffs post-commit, discovers unknowns before planning
- **Librarian** (librarian.md) fetches library docs for unfamiliar APIs
- **Designer** (designer.md) implements UI/UX; commits to step branch and halts before PR (fixer takes over)
- **Discuss** (discuss.md) pre-work scoping; surfaces decisions before implementation begins
- **Plan-plus-executor** (plan-plus-executor.md) ephemeral agent for single plan steps with context files; does not persist in main thread
