# plugin/skills/

# plugin/skills/ Codemap

## Responsibility

This directory defines the orchestrator's skill library—structured workflows that guide AI agents through complex tasks (debugging, testing, planning, mapping, finishing work). Each `.md` file is a reusable skill that encapsulates a decision tree, process flow, and output format. The skills collectively form the lean-flow methodology: task classification → pre-work (discuss, research, assumptions) → execution (TDD, planning, fixer dispatch) → verification (testing, code review, branch completion).

## Design

Skills follow a consistent template: name/description frontmatter, overview section, step-by-step process with decision points, output formats with examples, and hard rules. Skills are categorized by phase:
- **Pre-work:** `discuss` (scope lock), `phase-researcher` (verify approach), `assumptions-analyzer` (find evidence gaps), `ingest-docs` (inherit prior decisions)
- **Exploration:** `map-codebase` (parallel agent analysis), `cartography` (two-tier codebase mapping), `delegate-to-haiku` (route mechanical tasks to cheaper agents)
- **Implementation:** `test-driven-development` (red-green-refactor), `systematic-debugging` (root-cause-first), `brainstorming` (design before code), `spike` (throwaway validation)
- **Completion:** `finishing-a-development-branch` (merge/PR workflow), `plan-checker` (pre-execution verification), `nyquist-auditor` (fill test gaps)
- **Meta:** `using-lean-flow` (master workflow guide), `delegate-to-haiku` (agent routing rules)

## Flow

Skills are invoked by orchestrator agents (opus, sonnet, haiku) based on task context. `using-lean-flow` routes incoming work to the correct skill sequence: simple tasks skip directly to fixer; medium tasks flow through discuss → research → plan → execute; bugs always trigger `systematic-debugging` first; features always require `test-driven-development`. Each skill outputs structured evidence (decision tables, checklists, file citations) that feed into the next skill, preventing context loss and enabling async agent handoffs.

## Integration

Skills hook into the orchestrator's task classification system and agent dispatch logic. `cartography` maintains `docs/CODEBASE_MAP.md` and per-folder `codemap.md` files (like this one) as read-only context for other skills. `delegate-to-haiku` defines which operations route to cheap (haiku) agents vs. expensive (sonnet/opus) reasoning. `systematic-debugging` feeds back into `test-driven-development` when bugs reveal untested code paths. Completion workflows (`finishing-a-development-branch`, `plan-checker`, `nyquist-auditor`) chain together to gate PRs. All skills reference confirmed decisions from `discuss` and `ingest-docs` to prevent contradictions.
