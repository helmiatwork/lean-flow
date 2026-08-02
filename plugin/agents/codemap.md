# plugin/agents/

# codemap.md — `plugin/agents/`

## Responsibility
Defines nine specialized AI agents that form the lean-flow plugin's execution backbone. Each agent is a Claude model variant with specific tools, constraints, and domain expertise. The orchestrator (main session) dispatches these agents for classified tasks: exploration, research, architecture review, code review, implementation, design, discussion, planning execution, and PR management.

## Design
Each agent is a standalone markdown file defining:
- **Metadata** (`name`, `description`, `model`, `tools`, optional `color`) — parsed by orchestrator to select model and tool set
- **Role & Superpowers** — explicit capabilities (e.g., `superpowers:executing-plans`, `superpowers:test-driven-development`)
- **Workflow contract** — exact behavior (e.g., fixer's end-to-end chain: implement → test → lint → PR → review loop → merge)
- **Off-scope routing** — table mapping task types to correct agent; agent returns `OFF-SCOPE: dispatch to <agent> — <brief>` if work falls outside
- **Hard constraints** — prohibitions (`oracle` has `tools: []`; `designer` never initiates PR; `fixer` skips code-reviewer on step branches)

Agents range from **read-only** (explorer, librarian, oracle) to **full execution** (fixer, designer). Oracle is think-only; fixer is end-to-end.

## Flow
**Orchestrator dispatch cycle:**
1. Classify user task (simple/medium/heavy via STAR)
2. If medium/heavy: orchestrator writes structured plan with exact code + paths
3. Dispatch appropriate agent(s) in parallel: `explorer` for discovery, `librarian` for docs, `fixer` for implementation, `designer` for UI, `discuss` for scoping ambiguity
4. **Fixer coordination**: fixer runs full chain (impl → test → lint → commit → PR → code-reviewer dispatch → oracle dispatch → apply feedback → merge)
5. **Code review chain**: fixer dispatches `code-reviewer` (sonnet, diff-level quality), then `oracle` (sonnet, architecture + final verdict)
6. **Explorer integration**: after fixer/designer commits, orchestrator dispatches explorer to fill `codemap.md` templates in changed folders
7. Orchestrator receives verdicts, updates PR state, verifies completion

**Hard cap:** 3 combined review rounds (code-reviewer + oracle). Round 4+ → human escalation.

## Integration
- **Orchestrator** (`orchestrator.md`): main session, classifies → plans → dispatches agents, never writes code for medium/heavy
- **Fixer** (`fixer.md`): end-to-end implementer; owns full PR chain; dispatches code-reviewer + oracle; integrates explorer for codemap updates
- **Code-Reviewer** (`code-reviewer.md`): diff-level quality (SOLID, patterns, coverage, naming); incremental review; sticky PR comment with verdict block
- **Oracle** (`oracle.md`): architecture + security + final PR approval; think-only (no file tools); receives explorer summaries; issues `APPROVED` or `CHANGES_REQUESTED`
- **Explorer** (`explorer.md`): read-only codebase scanner; finds files fast; fills codemap.md templates; provides diff summaries to oracle
- **Librarian** (`librarian.md`): read-only research; fetches
